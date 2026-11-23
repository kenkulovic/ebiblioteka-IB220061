using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IAuthService
{
    Task<LoginResponseDto> LoginAsync(LoginRequestDto request);
    Task<LoginResponseDto> RegisterAsync(RegisterDto dto);
}
