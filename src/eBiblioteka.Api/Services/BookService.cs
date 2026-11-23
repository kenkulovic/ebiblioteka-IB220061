using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Data.Enums;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Helpers;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class BookService : IBookService
{
    private const long MaxCoverBytes = 2 * 1024 * 1024;

    private readonly AppDbContext _db;

    public BookService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<PagedResultDto<BookListItemDto>> GetAsync(BookQueryDto query)
    {
        var books = _db.Books.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            books = books.Where(b =>
                b.Title.Contains(search) ||
                b.BookAuthors.Any(ba =>
                    (ba.Author.FirstName + " " + ba.Author.LastName).Contains(search)));
        }

        if (query.CategoryId.HasValue)
        {
            books = books.Where(b => b.CategoryId == query.CategoryId.Value);
        }

        if (query.AuthorId.HasValue)
        {
            books = books.Where(b => b.BookAuthors.Any(ba => ba.AuthorId == query.AuthorId.Value));
        }

        if (query.OnlyAvailable)
        {
            books = books.Where(b => b.TotalCopies >
                _db.Loans.Count(l => l.BookId == b.Id && l.Status == LoanStatus.Active) +
                _db.Reservations.Count(r => r.BookId == b.Id && r.Status == ReservationStatus.Confirmed));
        }

        return await books
            .OrderBy(b => b.Title)
            .Select(b => new BookListItemDto
            {
                Id = b.Id,
                Title = b.Title,
                PublishedYear = b.PublishedYear,
                CategoryId = b.CategoryId,
                CategoryName = b.Category.Name,
                Authors = b.BookAuthors
                    .Select(ba => ba.Author.FirstName + " " + ba.Author.LastName)
                    .ToList(),
                TotalCopies = b.TotalCopies,
                AvailableCopies = b.TotalCopies
                    - _db.Loans.Count(l => l.BookId == b.Id && l.Status == LoanStatus.Active)
                    - _db.Reservations.Count(r => r.BookId == b.Id && r.Status == ReservationStatus.Confirmed),
                AverageRating = _db.Reviews
                    .Where(r => r.BookId == b.Id)
                    .Average(r => (double?)r.Rating),
                HasCover = b.CoverImage != null
            })
            .ToPagedAsync(query);
    }

    public async Task<BookDetailsDto> GetByIdAsync(int id)
    {
        return await _db.Books.AsNoTracking()
            .Where(b => b.Id == id)
            .Select(b => new BookDetailsDto
            {
                Id = b.Id,
                Title = b.Title,
                PublishedYear = b.PublishedYear,
                PageCount = b.PageCount,
                Description = b.Description,
                TotalCopies = b.TotalCopies,
                AvailableCopies = b.TotalCopies
                    - _db.Loans.Count(l => l.BookId == b.Id && l.Status == LoanStatus.Active)
                    - _db.Reservations.Count(r => r.BookId == b.Id && r.Status == ReservationStatus.Confirmed),
                CategoryId = b.CategoryId,
                CategoryName = b.Category.Name,
                PublisherId = b.PublisherId,
                PublisherName = b.Publisher != null ? b.Publisher.Name : null,
                Authors = b.BookAuthors
                    .Select(ba => new BookAuthorDto
                    {
                        Id = ba.AuthorId,
                        FullName = ba.Author.FirstName + " " + ba.Author.LastName
                    })
                    .ToList(),
                AverageRating = _db.Reviews
                    .Where(r => r.BookId == b.Id)
                    .Average(r => (double?)r.Rating),
                ReviewCount = _db.Reviews.Count(r => r.BookId == b.Id),
                HasCover = b.CoverImage != null
            })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Knjiga nije pronađena.");
    }

    public async Task<BookDetailsDto> CreateAsync(BookUpsertDto dto)
    {
        var authorIds = await ValidateAsync(dto);

        var book = new Book();
        Apply(book, dto);
        foreach (var authorId in authorIds)
        {
            book.BookAuthors.Add(new BookAuthor { AuthorId = authorId });
        }

        _db.Books.Add(book);
        await _db.SaveChangesAsync();

        return await GetByIdAsync(book.Id);
    }

    public async Task<BookDetailsDto> UpdateAsync(int id, BookUpsertDto dto)
    {
        var book = await _db.Books.Include(b => b.BookAuthors).FirstOrDefaultAsync(b => b.Id == id)
            ?? throw new NotFoundException("Knjiga nije pronađena.");

        var authorIds = await ValidateAsync(dto);

        var taken = await _db.Loans.CountAsync(l => l.BookId == id && l.Status == LoanStatus.Active)
            + await _db.Reservations.CountAsync(r => r.BookId == id && r.Status == ReservationStatus.Confirmed);
        if (dto.TotalCopies < taken)
        {
            throw new ConflictException(
                $"Broj primjeraka ne može biti manji od broja trenutno zauzetih primjeraka ({taken}).");
        }

        Apply(book, dto);

        _db.BookAuthors.RemoveRange(book.BookAuthors.Where(ba => !authorIds.Contains(ba.AuthorId)));
        var existing = book.BookAuthors.Select(ba => ba.AuthorId).ToHashSet();
        foreach (var authorId in authorIds.Where(a => !existing.Contains(a)))
        {
            book.BookAuthors.Add(new BookAuthor { AuthorId = authorId });
        }

        await _db.SaveChangesAsync();

        return await GetByIdAsync(id);
    }

    public async Task DeleteAsync(int id)
    {
        var book = await _db.Books.FindAsync(id)
            ?? throw new NotFoundException("Knjiga nije pronađena.");

        if (await _db.Loans.AnyAsync(l => l.BookId == id) ||
            await _db.Reservations.AnyAsync(r => r.BookId == id) ||
            await _db.Reviews.AnyAsync(r => r.BookId == id))
        {
            throw new ConflictException(
                "Knjiga se ne može obrisati jer postoje posudbe, rezervacije ili recenzije vezane za nju.");
        }

        // Izračunate sličnosti su izvedeni podaci i brišu se zajedno s knjigom.
        var similarities = _db.BookSimilarities.Where(s => s.BookId == id || s.SimilarBookId == id);
        _db.BookSimilarities.RemoveRange(similarities);
        _db.Books.Remove(book);
        await _db.SaveChangesAsync();
    }

    public async Task<BookCoverDto> GetCoverAsync(int id)
    {
        var cover = await _db.Books.AsNoTracking()
            .Where(b => b.Id == id)
            .Select(b => b.CoverImage)
            .FirstOrDefaultAsync();

        if (cover == null || cover.Length == 0)
        {
            throw new NotFoundException("Knjiga nema sliku korica.");
        }

        return new BookCoverDto
        {
            Data = cover,
            ContentType = ImageFormat.Detect(cover) ?? ImageFormat.Jpeg
        };
    }

    public async Task SetCoverAsync(int id, Stream content, long length)
    {
        var book = await _db.Books.FindAsync(id)
            ?? throw new NotFoundException("Knjiga nije pronađena.");

        if (length <= 0 || length > MaxCoverBytes)
        {
            throw new BadRequestException("Slika mora biti veličine do 2 MB.");
        }

        using var buffer = new MemoryStream();
        await content.CopyToAsync(buffer);
        var data = buffer.ToArray();

        if (ImageFormat.Detect(data) == null)
        {
            throw new BadRequestException("Dozvoljeni formati slike su PNG i JPEG.");
        }

        book.CoverImage = data;
        await _db.SaveChangesAsync();
    }

    public async Task RemoveCoverAsync(int id)
    {
        var book = await _db.Books.FindAsync(id)
            ?? throw new NotFoundException("Knjiga nije pronađena.");

        book.CoverImage = null;
        await _db.SaveChangesAsync();
    }

    private async Task<List<int>> ValidateAsync(BookUpsertDto dto)
    {
        if (!await _db.Categories.AnyAsync(c => c.Id == dto.CategoryId))
        {
            throw new BadRequestException("Odabrana kategorija ne postoji.");
        }

        if (dto.PublisherId.HasValue &&
            !await _db.Publishers.AnyAsync(p => p.Id == dto.PublisherId.Value))
        {
            throw new BadRequestException("Odabrani izdavač ne postoji.");
        }

        var authorIds = dto.AuthorIds.Distinct().ToList();
        var existingCount = await _db.Authors.CountAsync(a => authorIds.Contains(a.Id));
        if (existingCount != authorIds.Count)
        {
            throw new BadRequestException("Jedan ili više odabranih autora ne postoji.");
        }

        return authorIds;
    }

    private static void Apply(Book book, BookUpsertDto dto)
    {
        book.Title = dto.Title.Trim();
        book.PublishedYear = dto.PublishedYear;
        book.PageCount = dto.PageCount;
        book.Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim();
        book.TotalCopies = dto.TotalCopies;
        book.CategoryId = dto.CategoryId;
        book.PublisherId = dto.PublisherId;
    }
}
