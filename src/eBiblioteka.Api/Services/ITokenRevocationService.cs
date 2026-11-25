namespace eBiblioteka.Api.Services;

public interface ITokenRevocationService
{
    // Token je važeći ako nije poništen odjavom i račun nije blokiran.
    Task<bool> IsTokenValidAsync(string jti);

    Task RevokeAsync(string accessToken, int userId);
}
