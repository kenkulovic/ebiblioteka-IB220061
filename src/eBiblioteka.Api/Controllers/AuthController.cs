using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly ICityService _cityService;

    public AuthController(IAuthService authService, ICityService cityService)
    {
        _authService = authService;
        _cityService = cityService;
    }

    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<ActionResult<LoginResponseDto>> Login(LoginRequestDto request)
    {
        var response = await _authService.LoginAsync(request);
        return Ok(response);
    }

    // Odjava poništava token na serveru: isti token se više ne prihvata.
    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        var token = await HttpContext.GetTokenAsync("access_token");
        if (token != null)
        {
            await _authService.LogoutAsync(token, User.GetUserId());
        }

        return NoContent();
    }

    [AllowAnonymous]
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordDto dto)
    {
        await _authService.ForgotPasswordAsync(dto);
        return NoContent();
    }

    [AllowAnonymous]
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordDto dto)
    {
        await _authService.ResetPasswordAsync(dto);
        return NoContent();
    }

    // Dio registracije: gradovi za padajuću listu na ekranu registracije, prije prijave.
    [AllowAnonymous]
    [HttpGet("register/cities")]
    public async Task<ActionResult<PagedResultDto<CityDto>>> RegisterCities([FromQuery] PagedQueryDto query)
        => Ok(await _cityService.GetAsync(query, null));

    [AllowAnonymous]
    [HttpPost("register")]
    public async Task<ActionResult<LoginResponseDto>> Register(RegisterDto dto)
    {
        var response = await _authService.RegisterAsync(dto);
        return Ok(response);
    }
}
