using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.Data;

namespace eBiblioteka.Api.Services;

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IJwtService _jwtService;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        UserManager<ApplicationUser> userManager,
        IJwtService jwtService,
        ILogger<AuthService> logger)
    {
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
}