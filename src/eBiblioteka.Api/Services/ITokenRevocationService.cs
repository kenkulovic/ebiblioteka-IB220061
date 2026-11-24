namespace eBiblioteka.Api.Services;

public interface ITokenRevocationService
{
    // Token je važeći ako nije poništen odjavom i račun nije blokiran.
    Task<bool> IsTokenValidAsync(string jti, int userId);

    Task RevokeAsync(string accessToken);
}
