using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Data.Enums;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Helpers;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class MemberService : IMemberService
{
    private const long MaxImageBytes = 2 * 1024 * 1024;

    private readonly AppDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly INotificationService _notifications;
    private readonly ILogger<MemberService> _logger;

    public MemberService(
        AppDbContext db,
        UserManager<ApplicationUser> userManager,
        INotificationService notifications,
        ILogger<MemberService> logger)
    {
        _db = db;
        _userManager = userManager;
        _notifications = notifications;
        _logger = logger;
    }

    public async Task<PagedResultDto<MemberDto>> GetAsync(MemberQueryDto query)
    {
        var members = MembersOnly(_db.Users.AsNoTracking());

        if (query.IsBlocked.HasValue)
        {
            members = members.Where(u => u.IsBlocked == query.IsBlocked.Value);
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            members = members.Where(u =>
                (u.FirstName + " " + u.LastName).Contains(search) ||
                u.MembershipNumber.Contains(search) ||
                u.UserName!.Contains(search) ||
                u.Email!.Contains(search));
        }

        return await Project(members.OrderBy(u => u.LastName).ThenBy(u => u.FirstName)).ToPagedAsync(query);
    }

    public async Task<MemberDto> GetByIdAsync(int id) =>
        await Project(_db.Users.AsNoTracking().Where(u => u.Id == id)).FirstOrDefaultAsync()
        ?? throw new NotFoundException("Član nije pronađen.");

    public async Task<MemberDto> UpdateProfileAsync(int userId, UpdateProfileDto dto)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString())
            ?? throw new NotFoundException("Korisnik nije pronađen.");

        if (!await _db.Cities.AnyAsync(c => c.Id == dto.CityId))
        {
            throw new BadRequestException("Odabrani grad ne postoji.");
        }

        user.FirstName = dto.FirstName.Trim();
        user.LastName = dto.LastName.Trim();
        user.CityId = dto.CityId;

        var email = dto.Email.Trim();
        if (!string.Equals(user.Email, email, StringComparison.OrdinalIgnoreCase))
        {
            var emailResult = await _userManager.SetEmailAsync(user, email);
            if (!emailResult.Succeeded)
            {
                throw IdentityErrors.ToException(emailResult);
            }
        }

        var result = await _userManager.UpdateAsync(user);
        if (!result.Succeeded)
        {
            throw IdentityErrors.ToException(result);
        }

        return await GetByIdAsync(userId);
    }

    public async Task ChangePasswordAsync(int userId, ChangePasswordDto dto)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString())
            ?? throw new NotFoundException("Korisnik nije pronađen.");

        var result = await _userManager.ChangePasswordAsync(user, dto.CurrentPassword, dto.NewPassword);
        if (!result.Succeeded)
        {
            throw IdentityErrors.ToException(result);
        }

        _logger.LogInformation("Korisnik {UserId} je promijenio lozinku", userId);
    }

    public async Task<ImageDto> GetImageAsync(int id, int actorId, bool isAdmin)
    {
        // Član smije vidjeti samo svoju sliku; tuđa se prikazuje kao nepostojeća.
        if (!isAdmin && id != actorId)
        {
            throw new NotFoundException("Profilna slika nije pronađena.");
        }

        var image = await _db.Users.AsNoTracking()
            .Where(u => u.Id == id)
            .Select(u => u.ProfileImage)
            .FirstOrDefaultAsync();

        if (image == null || image.Length == 0)
        {
            throw new NotFoundException("Profilna slika nije pronađena.");
        }

        return new ImageDto
        {
            Data = image,
            ContentType = ImageFormat.Detect(image) ?? ImageFormat.Jpeg
        };
    }

    public async Task SetImageAsync(int userId, Stream content, long length)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId)
            ?? throw new NotFoundException("Korisnik nije pronađen.");

        if (length <= 0 || length > MaxImageBytes)
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

        user.ProfileImage = data;
        await _db.SaveChangesAsync();
    }

    public async Task RemoveImageAsync(int userId)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId)
            ?? throw new NotFoundException("Korisnik nije pronađen.");

        user.ProfileImage = null;
        await _db.SaveChangesAsync();
    }

    public async Task<MemberDto> BlockAsync(int adminId, int memberId, string reason)
    {
        var member = await FindMemberAsync(memberId);

        if (member.IsBlocked)
        {
            throw new ConflictException("Član je već blokiran.");
        }

        member.IsBlocked = true;
        member.BlockReason = reason.Trim();

        _notifications.Add(memberId, "Račun blokiran",
            $"Vaš račun je blokiran. Razlog: {member.BlockReason}");

        await _db.SaveChangesAsync();

        _logger.LogInformation("Član {MemberId} blokiran (bibliotekar {AdminId})", memberId, adminId);

        return await GetByIdAsync(memberId);
    }

    public async Task<MemberDto> UnblockAsync(int adminId, int memberId)
    {
        var member = await FindMemberAsync(memberId);

        if (!member.IsBlocked)
        {
            throw new ConflictException("Član nije blokiran.");
        }

        member.IsBlocked = false;
        member.BlockReason = null;

        _notifications.Add(memberId, "Račun odblokiran", "Vaš račun je ponovo aktivan.");

        await _db.SaveChangesAsync();

        _logger.LogInformation("Član {MemberId} odblokiran (bibliotekar {AdminId})", memberId, adminId);

        return await GetByIdAsync(memberId);
    }

    private async Task<ApplicationUser> FindMemberAsync(int memberId) =>
        await MembersOnly(_db.Users).FirstOrDefaultAsync(u => u.Id == memberId)
        ?? throw new NotFoundException("Član nije pronađen.");

    // Članovi su samo korisnici s ulogom Member (administratori se ne prikazuju kao članovi).
    private IQueryable<ApplicationUser> MembersOnly(IQueryable<ApplicationUser> users) =>
        users.Where(u => _db.UserRoles.Any(ur =>
            ur.UserId == u.Id &&
            _db.Roles.Any(r => r.Id == ur.RoleId && r.Name == Roles.Member)));

    private IQueryable<MemberDto> Project(IQueryable<ApplicationUser> users) =>
        users.Select(u => new MemberDto
        {
            Id = u.Id,
            UserName = u.UserName!,
            FirstName = u.FirstName,
            LastName = u.LastName,
            Email = u.Email ?? string.Empty,
            MembershipNumber = u.MembershipNumber,
            CityId = u.CityId,
            CityName = u.City.Name,
            IsBlocked = u.IsBlocked,
            BlockReason = u.BlockReason,
            CreatedAt = u.CreatedAt,
            HasProfileImage = u.ProfileImage != null,
            ActiveLoans = _db.Loans.Count(l => l.UserId == u.Id && l.Status == LoanStatus.Active),
            OpenReservations = _db.Reservations.Count(r =>
                r.UserId == u.Id &&
                (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed)),
            UnpaidFines = _db.Fines.Count(f => f.UserId == u.Id && f.Status == FineStatus.Unpaid)
        });
}
