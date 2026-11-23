using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class CountryService : ICountryService
{
    private readonly AppDbContext _db;

    public CountryService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<PagedResultDto<LookupDto>> GetAsync(PagedQueryDto query)
    {
        var countries = _db.Countries.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            countries = countries.Where(c => c.Name.Contains(query.Search));
        }

        return await countries
            .OrderBy(c => c.Name)
            .Select(c => new LookupDto { Id = c.Id, Name = c.Name })
            .ToPagedAsync(query);
    }

    public async Task<LookupDto> GetByIdAsync(int id)
    {
        return await _db.Countries.AsNoTracking()
            .Where(c => c.Id == id)
            .Select(c => new LookupDto { Id = c.Id, Name = c.Name })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Država nije pronađena.");
    }

    public async Task<LookupDto> CreateAsync(LookupUpsertDto dto)
    {
        var name = dto.Name.Trim();
        if (await _db.Countries.AnyAsync(c => c.Name == name))
        {
            throw new ConflictException("Država s tim nazivom već postoji.");
        }

        var country = new Country { Name = name };
        _db.Countries.Add(country);
        await _db.SaveChangesAsync();

        return new LookupDto { Id = country.Id, Name = country.Name };
    }

    public async Task<LookupDto> UpdateAsync(int id, LookupUpsertDto dto)
    {
        var country = await _db.Countries.FindAsync(id)
            ?? throw new NotFoundException("Država nije pronađena.");

        var name = dto.Name.Trim();
        if (await _db.Countries.AnyAsync(c => c.Name == name && c.Id != id))
        {
            throw new ConflictException("Država s tim nazivom već postoji.");
        }

        country.Name = name;
        await _db.SaveChangesAsync();

        return new LookupDto { Id = country.Id, Name = country.Name };
    }

    public async Task DeleteAsync(int id)
    {
        var country = await _db.Countries.FindAsync(id)
            ?? throw new NotFoundException("Država nije pronađena.");

        if (await _db.Cities.AnyAsync(c => c.CountryId == id) ||
            await _db.Authors.AnyAsync(a => a.CountryId == id))
        {
            throw new ConflictException("Država se ne može obrisati jer je koriste gradovi ili autori.");
        }

        _db.Countries.Remove(country);
        await _db.SaveChangesAsync();
    }
}
