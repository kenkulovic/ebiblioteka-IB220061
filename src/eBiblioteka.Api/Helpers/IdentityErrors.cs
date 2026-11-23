using eBiblioteka.Api.Exceptions;
using Microsoft.AspNetCore.Identity;

namespace eBiblioteka.Api.Helpers;

public static class IdentityErrors
{
    // Prevodi greške ASP.NET Identityja u naše izuzetke s porukama na bosanskom.
    public static Exception ToException(IdentityResult result)
    {
        var error = result.Errors.First();

        return error.Code switch
        {
            nameof(IdentityErrorDescriber.DuplicateUserName) =>
                new ConflictException("Korisničko ime je već zauzeto."),
            nameof(IdentityErrorDescriber.DuplicateEmail) =>
                new ConflictException("E-mail adresa je već u upotrebi."),
            nameof(IdentityErrorDescriber.InvalidEmail) =>
                new BadRequestException("E-mail adresa nije ispravna."),
            nameof(IdentityErrorDescriber.InvalidUserName) =>
                new BadRequestException("Korisničko ime sadrži nedozvoljene znakove."),
            nameof(IdentityErrorDescriber.PasswordTooShort) =>
                new BadRequestException("Lozinka je prekratka (najmanje 4 znaka)."),
            nameof(IdentityErrorDescriber.PasswordMismatch) =>
                new BadRequestException("Trenutna lozinka nije ispravna."),
            _ => new BadRequestException(string.Join(" ", result.Errors.Select(e => e.Description)))
        };
    }
}
