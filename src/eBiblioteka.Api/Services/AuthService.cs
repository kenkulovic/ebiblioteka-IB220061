using System.Data;
using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Helpers;
using eBiblioteka.Api.Services.Email;
using eBiblioteka.Shared.Messaging;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class AuthService : IAuthService
{
    private const string MembershipPrefix = "CL-";

    private readonly AppDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IJwtService _jwtService;
    private readonly IEmailQueue _emailQueue;
    private readonly ITokenRevocationService _revocation;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        AppDbContext db,
        UserManager<ApplicationUser> userManager,
        IJwtService jwtService,
        IEmailQueue emailQueue,
        ITokenRevocationService revocation,
        ILogger<AuthService> logger)
    {
        _db = db;
        _userManager = userManager;
        _jwtService = jwtService;
        _emailQueue = emailQueue;
        _revocation = revocation;
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
            PhoneNumber = string.IsNullOrWhiteSpace(dto.PhoneNumber) ? null : dto.PhoneNumber.Trim(),
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

        var welcome = $"Poštovani/a {user.FirstName},\n\n" +
                      $"Dobrodošli u eBiblioteku! Vaš broj članske karte je {user.MembershipNumber}.\n" +
                      "Možete pretraživati knjige, rezervisati ih i pratiti svoje posudbe u aplikaciji.\n\n" +
                      "eBiblioteka";
        try
        {
            await _emailQueue.EnqueueAsync(new EmailMessage(user.Email!, "Dobrodošli u eBiblioteku", welcome));
        }
        catch (Exception ex)
        {
            // Registracija je uspjela; neuspjelo slanje e-maila dobrodošlice je ne smije poništiti.
            _logger.LogWarning(ex, "E-mail dobrodošlice nije stavljen u red za korisnika {UserId}", user.Id);
        }

        _logger.LogInformation("Registrovan novi član {UserName} ({MembershipNumber})",
            user.UserName, user.MembershipNumber);

        return await LoginAsync(new LoginRequestDto { UserName = dto.UserName.Trim(), Password = dto.Password });
    }

    public Task LogoutAsync(string accessToken, int userId) => _revocation.RevokeAsync(accessToken, userId);

    public async Task ForgotPasswordAsync(ForgotPasswordDto dto)
    {
        // Odgovor je isti bez obzira postoji li e-mail, da se ne može saznati ko ima račun.
        var user = await _userManager.FindByEmailAsync(dto.Email.Trim());
        if (user == null)
        {
            _logger.LogInformation("Zahtjev za reset lozinke za nepoznat e-mail");
            return;
        }

        // Kod je šestocifren i vezan za račun; ograničeno vrijeme važenja (nekoliko minuta).
        var code = await _userManager.GeneratePasswordResetTokenAsync(user);

        var body = $"Poštovani/a {user.FirstName},\n\n" +
                   $"Vaš kod za promjenu lozinke je: {code}\n\n" +
                   "Kod važi nekoliko minuta. Ako niste tražili promjenu lozinke, zanemarite ovu poruku.\n\n" +
                   "eBiblioteka";
        await _emailQueue.EnqueueAsync(new EmailMessage(user.Email!, "eBiblioteka: kod za promjenu lozinke", body));

        _logger.LogInformation("Poslan kod za reset lozinke korisniku {UserId}", user.Id);
    }

    public async Task ResetPasswordAsync(ResetPasswordDto dto)
    {
        const string invalidMessage = "Kod nije ispravan ili je istekao.";

        var user = await _userManager.FindByEmailAsync(dto.Email.Trim())
            ?? throw new BadRequestException(invalidMessage);

        // Šestocifren kod bi se mogao pogađati: nakon više promašaja račun se privremeno zaključava.
        if (await _userManager.IsLockedOutAsync(user))
        {
            throw new ConflictException("Previše neispravnih pokušaja. Pokušajte ponovo kasnije.");
        }

        await using var transaction = await _db.Database.BeginTransactionAsync();

        var result = await _userManager.ResetPasswordAsync(user, dto.Code.Trim(), dto.NewPassword);
        if (!result.Succeeded)
        {
            // Brojač promašaja mora ostati zapisan, pa se snima izvan transakcije.
            await transaction.RollbackAsync();

            if (result.Errors.Any(e => e.Code == nameof(IdentityErrorDescriber.InvalidToken)))
            {
                await _userManager.AccessFailedAsync(user);
                _logger.LogWarning("Neispravan kod za reset lozinke za korisnika {UserId}", user.Id);
            }

            throw IdentityErrors.ToException(result);
        }

        await _userManager.ResetAccessFailedCountAsync(user);
        await transaction.CommitAsync();
        _logger.LogInformation("Lozinka korisnika {UserId} je promijenjena kodom iz e-maila", user.Id);
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
