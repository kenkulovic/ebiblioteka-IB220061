using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class AuthorService : IAuthorService
{
    private readonly AppDbContext _db;

    public AuthorService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<PagedResultDto<AuthorDto>> GetAsync(PagedQueryDto query)
    {
        var authors = _db.Authors.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            authors = authors.Where(a =>
                a.FirstName.Contains(search) ||
                a.LastName.Contains(search) ||
                (a.FirstName + " " + a.LastName).Contains(search));
        }

        return await ProjectToDto(authors.OrderBy(a => a.LastName).ThenBy(a => a.FirstName))
            .ToPagedAsync(query);
    }

    public async Task<AuthorDto> GetByIdAsync(int id)
    {
        return await ProjectToDto(_db.Authors.AsNoTracking().Where(a => a.Id == id))
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Autor nije pronađen.");
    }

    public async Task<AuthorDto> CreateAsync(AuthorUpsertDto dto)
    {
        await EnsureCountryExistsAsync(dto.CountryId);

        var author = new Author();
        Apply(author, dto);
        _db.Authors.Add(author);
        await _db.SaveChangesAsync();

        return await GetByIdAsync(author.Id);
    }

    public async Task<AuthorDto> UpdateAsync(int id, AuthorUpsertDto dto)
    {
        var author = await _db.Authors.FindAsync(id)
            ?? throw new NotFoundException("Autor nije pronađen.");

        await EnsureCountryExistsAsync(dto.CountryId);

        Apply(author, dto);
        await _db.SaveChangesAsync();

        return await GetByIdAsync(id);
    }

    public async Task DeleteAsync(int id)
    {
        var author = await _db.Authors.FindAsync(id)
            ?? throw new NotFoundException("Autor nije pronađen.");

        if (await _db.BookAuthors.AnyAsync(ba => ba.AuthorId == id))
        {
            throw new ConflictException("Autor se ne može obrisati jer ima knjige u katalogu.");
        }

        _db.Authors.Remove(author);
        await _db.SaveChangesAsync();
    }

    private static IQueryable<AuthorDto> ProjectToDto(IQueryable<Author> authors) =>
        authors.Select(a => new AuthorDto
        {
            Id = a.Id,
            FirstName = a.FirstName,
            LastName = a.LastName,
            Biography = a.Biography,
            CountryId = a.CountryId,
            CountryName = a.Country.Name,
            BookCount = a.BookAuthors.Count
        });

    private static void Apply(Author author, AuthorUpsertDto dto)
    {
        author.FirstName = dto.FirstName.Trim();
        author.LastName = dto.LastName.Trim();
        author.Biography = string.IsNullOrWhiteSpace(dto.Biography) ? null : dto.Biography.Trim();
        author.CountryId = dto.CountryId;
    }

    private async Task EnsureCountryExistsAsync(int countryId)
    {
        if (!await _db.Countries.AnyAsync(c => c.Id == countryId))
        {
            throw new BadRequestException("Odabrana država ne postoji.");
        }
    }
}
