using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class CityService : ICityService
{
    private readonly AppDbContext _db;

    public CityService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<PagedResultDto<CityDto>> GetAsync(PagedQueryDto query, int? countryId)
    {
        var cities = _db.Cities.AsNoTracking();

        if (countryId.HasValue)
        {
            cities = cities.Where(c => c.CountryId == countryId.Value);
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            cities = cities.Where(c => c.Name.Contains(query.Search));
        }

        return await cities
            .OrderBy(c => c.Name)
            .Select(c => new CityDto
            {
                Id = c.Id,
                Name = c.Name,
                CountryId = c.CountryId,
                CountryName = c.Country.Name,
                UsageCount = _db.Publishers.Count(p => p.CityId == c.Id) + _db.Users.Count(u => u.CityId == c.Id)
            })
            .ToPagedAsync(query);
    }

    public async Task<CityDto> GetByIdAsync(int id)
    {
        return await _db.Cities.AsNoTracking()
            .Where(c => c.Id == id)
            .Select(c => new CityDto
            {
                Id = c.Id,
                Name = c.Name,
                CountryId = c.CountryId,
                CountryName = c.Country.Name
            })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Grad nije pronađen.");
    }

    public async Task<CityDto> CreateAsync(CityUpsertDto dto)
    {
        var name = dto.Name.Trim();
        await EnsureValidAsync(name, dto.CountryId, null);

        var city = new City { Name = name, CountryId = dto.CountryId };
        _db.Cities.Add(city);
        await _db.SaveChangesAsync();

        return await GetByIdAsync(city.Id);
    }

    public async Task<CityDto> UpdateAsync(int id, CityUpsertDto dto)
    {
        var city = await _db.Cities.FindAsync(id)
            ?? throw new NotFoundException("Grad nije pronađen.");

        var name = dto.Name.Trim();
        await EnsureValidAsync(name, dto.CountryId, id);

        city.Name = name;
        city.CountryId = dto.CountryId;
        await _db.SaveChangesAsync();

        return await GetByIdAsync(id);
    }

    public async Task DeleteAsync(int id)
    {
        var city = await _db.Cities.FindAsync(id)
            ?? throw new NotFoundException("Grad nije pronađen.");

        var publisherCount = await _db.Publishers.CountAsync(p => p.CityId == id);
        var memberCount = await _db.Users.CountAsync(u => u.CityId == id);
        if (publisherCount + memberCount > 0)
        {
            throw new ConflictException(
                $"Grad se ne može obrisati jer ga koriste izdavači ({publisherCount}) ili članovi ({memberCount}).");
        }

        _db.Cities.Remove(city);
        await _db.SaveChangesAsync();
    }

    private async Task EnsureValidAsync(string name, int countryId, int? currentId)
    {
        if (!await _db.Countries.AnyAsync(c => c.Id == countryId))
        {
            throw new BadRequestException("Odabrana država ne postoji.");
        }

        if (await _db.Cities.AnyAsync(c => c.Name == name && c.Id != currentId))
        {
            throw new ConflictException("Grad s tim nazivom već postoji.");
        }
    }
}
