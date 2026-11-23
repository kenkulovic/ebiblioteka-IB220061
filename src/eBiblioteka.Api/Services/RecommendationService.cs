using System.Globalization;
using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Data.Enums;
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
        var interactions = await LoadInteractionsAsync(null);
        var results = SimilarityCalculator.Calculate(interactions);
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
            "Preračunata sličnost knjiga: {Pairs} zapisa iz {Interactions} interakcija ({Users} članova)",
            results.Count, interactions.Count, interactions.Select(i => i.UserId).Distinct().Count());

        return results.Count;
    }

    public async Task<List<RecommendationDto>> GetForUserAsync(int userId, int count)
    {
        count = Math.Clamp(count, 1, RecommenderSettings.MaxCount);

        var mine = await LoadInteractionsAsync(userId);
        var weights = mine.ToDictionary(i => i.BookId, i => i.Weight);

        // Ne preporučuju se knjige koje je član već posuđivao ili ih trenutno rezerviše.
        var openReservations = await _db.Reservations.AsNoTracking()
            .Where(r => r.UserId == userId &&
                        (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed))
            .Select(r => r.BookId)
            .ToListAsync();
        var excluded = weights.Keys.Concat(openReservations).Distinct().ToList();

        var ranked = new List<(int BookId, double Score, List<RecommendationReasonDto> Reasons)>();

        if (weights.Count > 0)
        {
            var sourceIds = weights.Keys.ToList();
            var neighbors = await _db.BookSimilarities.AsNoTracking()
                .Where(s => sourceIds.Contains(s.BookId) && !excluded.Contains(s.SimilarBookId))
                .Select(s => new { s.BookId, s.SimilarBookId, s.Similarity, s.CommonUsers })
                .ToListAsync();

            var titles = await _db.Books.AsNoTracking()
                .Where(b => sourceIds.Contains(b.Id))
                .ToDictionaryAsync(b => b.Id, b => b.Title);

            // Ocjena kandidata = zbir (sličnost sa knjigom koju je član čitao * težina te knjige).
            // Više različitih povoda i veća težina znače višu ocjenu.
            ranked = neighbors
                .GroupBy(n => n.SimilarBookId)
                .Select(g => (
                    BookId: g.Key,
                    Score: g.Sum(n => n.Similarity * weights[n.BookId]),
                    Reasons: g.OrderByDescending(n => n.Similarity * weights[n.BookId])
                        .Take(RecommenderSettings.ReasonsPerRecommendation)
                        .Select(n => new RecommendationReasonDto
                        {
                            BookId = n.BookId,
                            BookTitle = titles[n.BookId],
                            Similarity = Math.Round(n.Similarity, 4),
                            CommonUsers = n.CommonUsers
                        })
                        .ToList()))
                .OrderByDescending(x => x.Score)
                .ThenBy(x => x.BookId)
                .Take(count)
                .ToList();
        }

        var popular = new List<(int BookId, int Loans)>();
        if (ranked.Count < count)
        {
            // Nedovoljno historije (novi član) ili premalo sličnih knjiga: popuna najpopularnijim knjigama.
            var skip = excluded.Concat(ranked.Select(r => r.BookId)).Distinct().ToList();
            var rows = await _db.Books.AsNoTracking()
                .Where(b => !skip.Contains(b.Id))
                .Select(b => new
                {
                    b.Id,
                    Loans = _db.Loans.Count(l => l.BookId == b.Id),
                    Average = _db.Reviews.Where(r => r.BookId == b.Id).Average(r => (double?)r.Rating)
                })
                .OrderByDescending(x => x.Loans)
                .ThenByDescending(x => x.Average)
                .ThenBy(x => x.Id)
                .Take(count - ranked.Count)
                .ToListAsync();
            popular = rows.Select(r => (r.Id, r.Loans)).ToList();
        }

        var ids = ranked.Select(r => r.BookId).Concat(popular.Select(p => p.BookId)).ToList();
        var items = (await _books.GetListItemsAsync(ids)).ToDictionary(b => b.Id);

        var result = new List<RecommendationDto>();
        foreach (var (bookId, score, reasons) in ranked)
        {
            result.Add(new RecommendationDto
            {
                Book = items[bookId],
                Score = Math.Round(score, 4),
                Source = "Similar",
                Reasons = reasons,
                Explanation = "Preporučeno jer ste čitali: " + string.Join("; ", reasons.Select(r =>
                    $"„{r.BookTitle}” (sličnost {Format(r.Similarity)}, zajedničkih čitalaca: {r.CommonUsers})")) + "."
            });
        }

        foreach (var (bookId, loans) in popular)
        {
            result.Add(new RecommendationDto
            {
                Book = items[bookId],
                Score = 0,
                Source = "Popular",
                Explanation = $"Popularno među članovima biblioteke (posudbi: {loans})."
            });
        }

        return result;
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

    // Jedna interakcija po paru (član, knjiga): prosjek ocjena ako postoje, inače neutralna težina.
    private async Task<List<Interaction>> LoadInteractionsAsync(int? userId)
    {
        var loans = _db.Loans.AsNoTracking().AsQueryable();
        if (userId.HasValue)
        {
            loans = loans.Where(l => l.UserId == userId.Value);
        }

        var rows = await loans
            .Select(l => new
            {
                l.UserId,
                l.BookId,
                Rating = _db.Reviews.Where(r => r.LoanId == l.Id).Select(r => (int?)r.Rating).FirstOrDefault()
            })
            .ToListAsync();

        return rows
            .GroupBy(r => (r.UserId, r.BookId))
            .Select(g =>
            {
                var ratings = g.Where(r => r.Rating.HasValue).Select(r => (double)r.Rating!.Value).ToList();
                return new Interaction(
                    g.Key.UserId,
                    g.Key.BookId,
                    SimilarityCalculator.WeightOf(ratings.Count > 0 ? ratings.Average() : null));
            })
            .ToList();
    }

    private static string Format(double value) =>
        value.ToString("0.00", CultureInfo.InvariantCulture).Replace('.', ',');
}
