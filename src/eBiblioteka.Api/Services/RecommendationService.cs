using System.Globalization;
using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Services.Recommender;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class RecommendationService : IRecommendationService
{
    private readonly AppDbContext _db;
    private readonly IBookService _books;
    private readonly ILogger<RecommendationService> _logger;

    public RecommendationService(AppDbContext db, IBookService books, ILogger<RecommendationService> logger)
    {
        _db = db;
        _books = books;
        _logger = logger;
    }

    public async Task<int> RecalculateAsync()
    {
        var ratings = await LoadRatingsAsync(null);
        var results = SimilarityCalculator.Calculate(ratings);
        var now = DateTime.UtcNow;

        // Brisanje stare i upis nove tabele su jedna cjelina: čitaoci nikad ne vide praznu tabelu.
        await using var transaction = await _db.Database.BeginTransactionAsync();

        await _db.BookSimilarities.ExecuteDeleteAsync();
        _db.BookSimilarities.AddRange(results.Select(r => new BookSimilarity
        {
            BookId = r.BookId,
            SimilarBookId = r.SimilarBookId,
            Similarity = r.Similarity,
            CommonUsers = r.CommonUsers,
            CalculatedAt = now
        }));
        await _db.SaveChangesAsync();

        await transaction.CommitAsync();

        _logger.LogInformation(
            "Preračunata sličnost knjiga: {Pairs} zapisa iz {Ratings} ocjena ({Users} članova)",
            results.Count, ratings.Count, ratings.Select(r => r.UserId).Distinct().Count());

        return results.Count;
    }

    public async Task<List<RecommendationDto>> GetForUserAsync(int userId, int count)
    {
        count = Math.Clamp(count, 1, RecommenderSettings.MaxCount);

        var myRatings = (await LoadRatingsAsync(userId)).ToDictionary(r => r.BookId, r => r.Value);

        // Ne preporučuju se knjige koje je član već posuđivao.
        var borrowed = await _db.Loans.AsNoTracking()
            .Where(l => l.UserId == userId)
            .Select(l => l.BookId)
            .Distinct()
            .ToListAsync();

        var ranked = myRatings.Count >= RecommenderSettings.MinUserRatings
            ? await PredictAsync(myRatings, borrowed, count)
            : new List<Prediction>();

        // Nedovoljno ocjena ili nijedna knjiga s dovoljno visokom predviđenom ocjenom: popularne knjige.
        if (ranked.Count == 0)
        {
            return await PopularAsync(borrowed, count);
        }

        var items = (await _books.GetListItemsAsync(ranked.Select(r => r.BookId).ToList()))
            .ToDictionary(b => b.Id);

        return ranked.Select(p => new RecommendationDto
        {
            Book = items[p.BookId],
            Score = Math.Round(p.PredictedRating, 2),
            Source = "Similar",
            Reasons = new List<RecommendationReasonDto> { p.Reason },
            Explanation = Explain(p.Reason)
        }).ToList();
    }

    public async Task<List<SimilarBookDto>> GetSimilarBooksAsync(int bookId, int count)
    {
        count = Math.Clamp(count, 1, RecommenderSettings.MaxCount);

        if (!await _db.Books.AnyAsync(b => b.Id == bookId))
        {
            throw new NotFoundException("Knjiga nije pronađena.");
        }

        var similar = await _db.BookSimilarities.AsNoTracking()
            .Where(s => s.BookId == bookId)
            .OrderByDescending(s => s.Similarity)
            .ThenByDescending(s => s.CommonUsers)
            .ThenBy(s => s.SimilarBookId)
            .Take(count)
            .Select(s => new { s.SimilarBookId, s.Similarity, s.CommonUsers })
            .ToListAsync();

        var items = (await _books.GetListItemsAsync(similar.Select(s => s.SimilarBookId).ToList()))
            .ToDictionary(b => b.Id);

        return similar.Select(s => new SimilarBookDto
        {
            Book = items[s.SimilarBookId],
            Similarity = Math.Round(s.Similarity, 4),
            CommonUsers = s.CommonUsers
        }).ToList();
    }

    // Predviđena ocjena knjige = ponderisani prosjek članovih ocjena do 10 najsličnijih knjiga koje je ocijenio
    // (težina je sličnost; koriste se samo pozitivne sličnosti, pa tabela i sadrži samo njih).
    private async Task<List<Prediction>> PredictAsync(
        Dictionary<int, double> myRatings, List<int> borrowed, int count)
    {
        var ratedIds = myRatings.Keys.ToList();

        var neighbors = await _db.BookSimilarities.AsNoTracking()
            .Where(s => ratedIds.Contains(s.BookId) && !borrowed.Contains(s.SimilarBookId))
            .Select(s => new { RatedBookId = s.BookId, CandidateId = s.SimilarBookId, s.Similarity, s.CommonUsers })
            .ToListAsync();

        var predictions = new List<(int BookId, double Predicted, int SourceBookId, double Similarity, int Common)>();

        foreach (var candidate in neighbors.GroupBy(n => n.CandidateId))
        {
            var nearest = candidate
                .OrderByDescending(n => n.Similarity)
                .Take(RecommenderSettings.NeighborsForPrediction)
                .ToList();

            var predicted = nearest.Sum(n => n.Similarity * myRatings[n.RatedBookId]) / nearest.Sum(n => n.Similarity);
            if (predicted < RecommenderSettings.MinPredictedRating)
            {
                continue;
            }

            // Knjiga koja je najviše doprinijela predviđanju: najveći proizvod sličnosti i članove ocjene.
            var best = nearest.MaxBy(n => n.Similarity * myRatings[n.RatedBookId])!;
            predictions.Add((candidate.Key, predicted, best.RatedBookId, best.Similarity, best.CommonUsers));
        }

        var top = predictions
            .OrderByDescending(p => p.Predicted)
            .ThenBy(p => p.BookId)
            .Take(count)
            .ToList();

        var titles = await _db.Books.AsNoTracking()
            .Where(b => top.Select(p => p.SourceBookId).Contains(b.Id))
            .ToDictionaryAsync(b => b.Id, b => b.Title);

        return top.Select(p => new Prediction(
            p.BookId,
            p.Predicted,
            new RecommendationReasonDto
            {
                BookId = p.SourceBookId,
                BookTitle = titles[p.SourceBookId],
                Similarity = Math.Round(p.Similarity, 4),
                CommonUsers = p.Common,
                UserRating = (int)Math.Round(myRatings[p.SourceBookId])
            })).ToList();
    }

    // Najviše posudbi u posljednjih 30 dana.
    private async Task<List<RecommendationDto>> PopularAsync(List<int> borrowed, int count)
    {
        var since = DateTime.UtcNow.AddDays(-RecommenderSettings.PopularDays);

        var popular = await _db.Loans.AsNoTracking()
            .Where(l => l.LoanDate >= since && !borrowed.Contains(l.BookId))
            .GroupBy(l => l.BookId)
            .Select(g => new { BookId = g.Key, Loans = g.Count() })
            .OrderByDescending(x => x.Loans)
            .ThenBy(x => x.BookId)
            .Take(count)
            .ToListAsync();

        var items = (await _books.GetListItemsAsync(popular.Select(p => p.BookId).ToList()))
            .ToDictionary(b => b.Id);

        return popular.Select(p => new RecommendationDto
        {
            Book = items[p.BookId],
            Score = 0,
            Source = "Popular",
            Explanation = "Najčešće posuđivano ovog mjeseca."
        }).ToList();
    }

    // Jedna ocjena po paru (član, knjiga): prosjek, ako je član više puta posuđivao i ocjenjivao istu knjigu.
    private async Task<List<Rating>> LoadRatingsAsync(int? userId)
    {
        var reviews = _db.Reviews.AsNoTracking().AsQueryable();
        if (userId.HasValue)
        {
            reviews = reviews.Where(r => r.UserId == userId.Value);
        }

        var rows = await reviews.Select(r => new { r.UserId, r.BookId, r.Rating }).ToListAsync();

        return rows
            .GroupBy(r => (r.UserId, r.BookId))
            .Select(g => new Rating(g.Key.UserId, g.Key.BookId, g.Average(r => r.Rating)))
            .ToList();
    }

    private static string Explain(RecommendationReasonDto reason)
    {
        var similarity = reason.Similarity.ToString("0.00", CultureInfo.InvariantCulture).Replace('.', ',');
        var verb = reason.UserRating >= RecommenderSettings.HighRating
            ? "visoko ocijenili"
            : $"ocijenili ocjenom {reason.UserRating}";

        return $"Zato što ste {verb} ‚{reason.BookTitle}‘ (sličnost {similarity})";
    }

    private sealed record Prediction(int BookId, double PredictedRating, RecommendationReasonDto Reason);
}
