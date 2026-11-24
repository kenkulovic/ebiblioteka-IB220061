using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IAuthService
{
    Task<LoginResponseDto> LoginAsync(LoginRequestDto request);
    Task<LoginResponseDto> RegisterAsync(RegisterDto dto);
    Task LogoutAsync(string accessToken);
    Task ForgotPasswordAsync(ForgotPasswordDto dto);
    Task ResetPasswordAsync(ResetPasswordDto dto);
}
