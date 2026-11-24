using eBiblioteka.Api.Dtos;
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

    public AuthController(IAuthService authService)
    {
        _authService = authService;
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
            await _authService.LogoutAsync(token);
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

    [AllowAnonymous]
    [HttpPost("register")]
    public async Task<ActionResult<LoginResponseDto>> Register(RegisterDto dto)
    {
        var response = await _authService.RegisterAsync(dto);
        return Ok(response);
    }
}
