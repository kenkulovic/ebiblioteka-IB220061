using System.Data;
using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Helpers;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class AuthService : IAuthService
{
    private const string MembershipPrefix = "CL-";

    private readonly AppDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IJwtService _jwtService;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        AppDbContext db,
        UserManager<ApplicationUser> userManager,
        IJwtService jwtService,
        ILogger<AuthService> logger)
    {
        _db = db;
        _userManager = userManager;
        _jwtService = jwtService;
        _logger = logger;
    }

    public async Task<LoginResponseDto> LoginAsync(LoginRequestDto request)
    {
        var user = await _userManager.FindByNameAsync(request.UserName);

        if (user == null || !await _userManager.CheckPasswordAsync(user, request.Password))
        {
            _logger.LogWarning("Neuspjela prijava za korisnika {UserName}", request.UserName);
            throw new UnauthorizedException("Pogrešno korisničko ime ili lozinka.");
        }

        if (user.IsBlocked)
        {
            _logger.LogWarning("Blokiran korisnik {UserName} pokušao se prijaviti", request.UserName);
            throw new ForbiddenException("Vaš račun je blokiran. Obratite se biblioteci.");
        }

        var roles = await _userManager.GetRolesAsync(user);
        var token = await _jwtService.CreateTokenAsync(user);

        _logger.LogInformation("Korisnik {UserName} se prijavio", user.UserName);

        return new LoginResponseDto
        {
            Token = token,
            UserId = user.Id,
            UserName = user.UserName!,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Roles = roles.ToList()
        };
    }

    public async Task<LoginResponseDto> RegisterAsync(RegisterDto dto)
    {
        if (!await _db.Cities.AnyAsync(c => c.Id == dto.CityId))
        {
            throw new BadRequestException("Odabrani grad ne postoji.");
        }

        // Serializable: dva istovremena registrovanja ne smiju dobiti isti broj članske karte.
        await using var transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable);

        var user = new ApplicationUser
        {
            UserName = dto.UserName.Trim(),
            Email = dto.Email.Trim(),
            EmailConfirmed = true,
            FirstName = dto.FirstName.Trim(),
            LastName = dto.LastName.Trim(),
            CityId = dto.CityId,
            MembershipNumber = await NextMembershipNumberAsync(),
            CreatedAt = DateTime.UtcNow
        };

        var result = await _userManager.CreateAsync(user, dto.Password);
        if (!result.Succeeded)
        {
            throw IdentityErrors.ToException(result);
        }

        var roleResult = await _userManager.AddToRoleAsync(user, Roles.Member);
        if (!roleResult.Succeeded)
        {
            throw IdentityErrors.ToException(roleResult);
        }

        await transaction.CommitAsync();

        _logger.LogInformation("Registrovan novi član {UserName} ({MembershipNumber})",
            user.UserName, user.MembershipNumber);

        return await LoginAsync(new LoginRequestDto { UserName = dto.UserName.Trim(), Password = dto.Password });
    }

    private async Task<string> NextMembershipNumberAsync()
    {
        var last = await _db.Users
            .Select(u => u.MembershipNumber)
            .OrderByDescending(n => n)
            .FirstOrDefaultAsync();

        var next = last != null &&
                   last.StartsWith(MembershipPrefix) &&
                   int.TryParse(last[MembershipPrefix.Length..], out var number)
            ? number + 1
            : 1;

        return $"{MembershipPrefix}{next:D6}";
    }
}
