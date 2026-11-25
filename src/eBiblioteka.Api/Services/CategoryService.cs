using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class CategoryService : ICategoryService
{
    private readonly AppDbContext _db;

    public CategoryService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<PagedResultDto<LookupDto>> GetAsync(PagedQueryDto query)
    {
        var categories = _db.Categories.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            categories = categories.Where(c => c.Name.Contains(query.Search));
        }

        var ordered = query.NewestFirst
            ? categories.OrderByDescending(c => c.Id)
            : categories.OrderBy(c => c.Name);

        return await ordered
            .Select(c => new LookupDto { Id = c.Id, Name = c.Name, UsageCount = _db.Books.Count(b => b.CategoryId == c.Id) })
            .ToPagedAsync(query);
    }

    public async Task<LookupDto> GetByIdAsync(int id)
    {
        return await _db.Categories.AsNoTracking()
            .Where(c => c.Id == id)
            .Select(c => new LookupDto { Id = c.Id, Name = c.Name })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Kategorija nije pronađena.");
    }

    public async Task<LookupDto> CreateAsync(LookupUpsertDto dto)
    {
        var name = dto.Name.Trim();
        if (await _db.Categories.AnyAsync(c => c.Name == name))
        {
            throw new ConflictException("Kategorija s tim nazivom već postoji.");
        }

        var category = new Category { Name = name };
        _db.Categories.Add(category);
        await _db.SaveChangesAsync();

        return new LookupDto { Id = category.Id, Name = category.Name };
    }

    public async Task<LookupDto> UpdateAsync(int id, LookupUpsertDto dto)
    {
        var category = await _db.Categories.FindAsync(id)
            ?? throw new NotFoundException("Kategorija nije pronađena.");

        var name = dto.Name.Trim();
        if (await _db.Categories.AnyAsync(c => c.Name == name && c.Id != id))
        {
            throw new ConflictException("Kategorija s tim nazivom već postoji.");
        }

        category.Name = name;
        await _db.SaveChangesAsync();

        return new LookupDto { Id = category.Id, Name = category.Name };
    }

    public async Task DeleteAsync(int id)
    {
        var category = await _db.Categories.FindAsync(id)
            ?? throw new NotFoundException("Kategorija nije pronađena.");

        var bookCount = await _db.Books.CountAsync(b => b.CategoryId == id);
        if (bookCount > 0)
        {
            throw new ConflictException(
                $"Kategorija se ne može obrisati jer postoje knjige u toj kategoriji ({bookCount}).");
        }

        _db.Categories.Remove(category);
        await _db.SaveChangesAsync();
    }
}
