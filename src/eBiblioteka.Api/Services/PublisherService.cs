using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class PublisherService : IPublisherService
{
    private readonly AppDbContext _db;

    public PublisherService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<PagedResultDto<PublisherDto>> GetAsync(PagedQueryDto query)
    {
        var publishers = _db.Publishers.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            publishers = publishers.Where(p => p.Name.Contains(query.Search));
        }

        var ordered = query.NewestFirst
            ? publishers.OrderByDescending(p => p.Id)
            : publishers.OrderBy(p => p.Name);

        return await ordered
            .Select(p => new PublisherDto
            {
                Id = p.Id,
                Name = p.Name,
                CityId = p.CityId,
                CityName = p.City.Name,
                UsageCount = _db.Books.Count(b => b.PublisherId == p.Id)
            })
            .ToPagedAsync(query);
    }

    public async Task<PublisherDto> GetByIdAsync(int id)
    {
        return await _db.Publishers.AsNoTracking()
            .Where(p => p.Id == id)
            .Select(p => new PublisherDto
            {
                Id = p.Id,
                Name = p.Name,
                CityId = p.CityId,
                CityName = p.City.Name
            })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Izdavač nije pronađen.");
    }

    public async Task<PublisherDto> CreateAsync(PublisherUpsertDto dto)
    {
        var name = dto.Name.Trim();
        await EnsureValidAsync(name, dto.CityId, null);

        var publisher = new Publisher { Name = name, CityId = dto.CityId };
        _db.Publishers.Add(publisher);
        await _db.SaveChangesAsync();

        return await GetByIdAsync(publisher.Id);
    }

    public async Task<PublisherDto> UpdateAsync(int id, PublisherUpsertDto dto)
    {
        var publisher = await _db.Publishers.FindAsync(id)
            ?? throw new NotFoundException("Izdavač nije pronađen.");

        var name = dto.Name.Trim();
        await EnsureValidAsync(name, dto.CityId, id);

        publisher.Name = name;
        publisher.CityId = dto.CityId;
        await _db.SaveChangesAsync();

        return await GetByIdAsync(id);
    }

    public async Task DeleteAsync(int id)
    {
        var publisher = await _db.Publishers.FindAsync(id)
            ?? throw new NotFoundException("Izdavač nije pronađen.");

        var bookCount = await _db.Books.CountAsync(b => b.PublisherId == id);
        if (bookCount > 0)
        {
            throw new ConflictException(
                $"Izdavač se ne može obrisati jer postoje knjige tog izdavača ({bookCount}).");
        }

        _db.Publishers.Remove(publisher);
        await _db.SaveChangesAsync();
    }

    private async Task EnsureValidAsync(string name, int cityId, int? currentId)
    {
        if (!await _db.Cities.AnyAsync(c => c.Id == cityId))
        {
            throw new BadRequestException("Odabrani grad ne postoji.");
        }

        if (await _db.Publishers.AnyAsync(p => p.Name == name && p.Id != currentId))
        {
            throw new ConflictException("Izdavač s tim nazivom već postoji.");
        }
    }
}
