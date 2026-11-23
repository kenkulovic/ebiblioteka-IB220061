using eBiblioteka.Api.Dtos;
using Microsoft.AspNetCore.Identity.Data;

namespace eBiblioteka.Api.Services;

public interface IAuthService
{
    Task<LoginResponseDto> LoginAsync(LoginRequestDto request);
}