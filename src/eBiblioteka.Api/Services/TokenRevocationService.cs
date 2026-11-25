using System.IdentityModel.Tokens.Jwt;
using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class TokenRevocationService : ITokenRevocationService
{
    private readonly AppDbContext _db;
    private readonly ILogger<TokenRevocationService> _logger;

    public TokenRevocationService(AppDbContext db, ILogger<TokenRevocationService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<bool> IsTokenValidAsync(string jti) =>
        !await _db.RevokedTokens.AnyAsync(t => t.Jti == jti);

    public async Task RevokeAsync(string accessToken, int userId)
    {
        var token = new JwtSecurityTokenHandler().ReadJwtToken(accessToken);

        if (!await _db.RevokedTokens.AnyAsync(t => t.Jti == token.Id))
        {
            _db.RevokedTokens.Add(new RevokedToken { Jti = token.Id, ExpiresAt = token.ValidTo, UserId = userId });
            await _db.SaveChangesAsync();
        }

        // Istekli tokeni se ionako odbijaju, pa se njihovi zapisi brišu.
        var removed = await _db.RevokedTokens.Where(t => t.ExpiresAt < DateTime.UtcNow).ExecuteDeleteAsync();
        _logger.LogInformation("Token {Jti} poništen odjavom (obrisano isteklih zapisa: {Removed})", token.Id, removed);
    }
}
