using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Data.Enums;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class ReviewService : IReviewService
{
    private readonly AppDbContext _db;
    private readonly ILogger<ReviewService> _logger;

    public ReviewService(AppDbContext db, ILogger<ReviewService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<ReviewDto> CreateAsync(int userId, ReviewCreateDto dto)
    {
        // Tuđa posudba se prikazuje kao nepostojeća.
        var loan = await _db.Loans.AsNoTracking()
            .Where(l => l.Id == dto.LoanId && l.UserId == userId)
            .Select(l => new { l.Id, l.BookId, l.Status })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Posudba nije pronađena.");

        if (loan.Status != LoanStatus.Returned)
        {
            throw new ConflictException("Ocijeniti se može samo vraćena knjiga.");
        }

        if (await _db.Reviews.AnyAsync(r => r.LoanId == loan.Id))
        {
            throw new ConflictException("Ova posudba je već ocijenjena.");
        }

        var review = new Review
        {
            LoanId = loan.Id,
            UserId = userId,
            BookId = loan.BookId,
            Rating = dto.Rating,
            Comment = string.IsNullOrWhiteSpace(dto.Comment) ? null : dto.Comment.Trim(),
            CreatedAt = DateTime.UtcNow
        };
        _db.Reviews.Add(review);
        await _db.SaveChangesAsync();

        _logger.LogInformation("Član {UserId} ocijenio knjigu {BookId} ocjenom {Rating}",
            userId, loan.BookId, dto.Rating);

        return await GetDtoAsync(review.Id);
    }

    public async Task<ReviewDto> UpdateAsync(int userId, int reviewId, ReviewUpdateDto dto)
    {
        var review = await _db.Reviews.FirstOrDefaultAsync(r => r.Id == reviewId && r.UserId == userId)
            ?? throw new NotFoundException("Ocjena nije pronađena.");

        review.Rating = dto.Rating;
        review.Comment = string.IsNullOrWhiteSpace(dto.Comment) ? null : dto.Comment.Trim();
        review.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return await GetDtoAsync(reviewId);
    }

    public async Task<PagedResultDto<ReviewDto>> GetForBookAsync(int bookId, PagedQueryDto query)
    {
        if (!await _db.Books.AnyAsync(b => b.Id == bookId))
        {
            throw new NotFoundException("Knjiga nije pronađena.");
        }

        return await Project(_db.Reviews.AsNoTracking().Where(r => r.BookId == bookId))
            .ToPagedAsync(query);
    }

    public async Task<PagedResultDto<ReviewDto>> GetMineAsync(int userId, PagedQueryDto query) =>
        await Project(_db.Reviews.AsNoTracking().Where(r => r.UserId == userId)).ToPagedAsync(query);

    private static IQueryable<ReviewDto> Project(IQueryable<Review> reviews) =>
        reviews
            .OrderByDescending(r => r.CreatedAt)
            .ThenByDescending(r => r.Id)
            .Select(r => new ReviewDto
            {
                Id = r.Id,
                Rating = r.Rating,
                Comment = r.Comment,
                CreatedAt = r.CreatedAt,
                UpdatedAt = r.UpdatedAt,
                LoanId = r.LoanId,
                UserId = r.UserId,
                UserFullName = r.User.FirstName + " " + r.User.LastName,
                BookId = r.BookId,
                BookTitle = r.Book.Title
            });

    private async Task<ReviewDto> GetDtoAsync(int id) =>
        await Project(_db.Reviews.AsNoTracking().Where(r => r.Id == id)).FirstAsync();
}
