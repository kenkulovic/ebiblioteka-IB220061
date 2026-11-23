using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Enums;
using eBiblioteka.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class MemberEligibilityService : IMemberEligibilityService
{
    private readonly AppDbContext _db;

    public MemberEligibilityService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<string?> GetRestrictionAsync(int userId)
    {
        var user = await _db.Users.AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => new { u.IsBlocked, u.BlockReason })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Član nije pronađen.");

        if (user.IsBlocked)
        {
            return string.IsNullOrWhiteSpace(user.BlockReason)
                ? "Račun je blokiran."
                : $"Račun je blokiran: {user.BlockReason}";
        }

        if (await _db.Fines.AnyAsync(f => f.UserId == userId && f.Status == FineStatus.Unpaid))
        {
            return "Postoji neplaćena zakasnina. Dok se ne plati, rezervacija i posudba knjiga nisu moguće.";
        }

        return null;
    }
}
