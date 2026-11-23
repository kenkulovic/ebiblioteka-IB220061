using eBiblioteka.Api.Data.Entities;

namespace eBiblioteka.Api.Services;

public interface IJwtService
{
    Task<string> CreateTokenAsync(ApplicationUser user);
}