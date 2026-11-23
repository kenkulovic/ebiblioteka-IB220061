using System.Security.Claims;
using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Exceptions;

namespace eBiblioteka.Api.Extensions;

public static class ClaimsPrincipalExtensions
{
    // Id korisnika se uvijek čita iz tokena, nikad iz zahtjeva klijenta.
    public static int GetUserId(this ClaimsPrincipal user)
    {
        var value = user.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(value, out var id))
        {
            throw new UnauthorizedException("Neispravan token.");
        }

        return id;
    }

    public static bool IsAdministrator(this ClaimsPrincipal user) => user.IsInRole(Roles.Administrator);
}
