using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class RegisterDto
{
    [Required(ErrorMessage = "Korisničko ime je obavezno.")]
    [StringLength(50, MinimumLength = 3, ErrorMessage = "Korisničko ime mora imati 3 do 50 znakova.")]
    public string UserName { get; set; } = string.Empty;

    [Required(ErrorMessage = "E-mail je obavezan.")]
    [EmailAddress(ErrorMessage = "Unesite e-mail adresu u formatu ime@domena.ba.")]
    [StringLength(100, ErrorMessage = "E-mail može imati najviše 100 znakova.")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Lozinka je obavezna.")]
    [StringLength(100, MinimumLength = 4, ErrorMessage = "Lozinka mora imati najmanje 4 znaka.")]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = "Ime je obavezno.")]
    [StringLength(50, ErrorMessage = "Ime može imati najviše 50 znakova.")]
    public string FirstName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Prezime je obavezno.")]
    [StringLength(50, ErrorMessage = "Prezime može imati najviše 50 znakova.")]
    public string LastName { get; set; } = string.Empty;

    [Range(1, int.MaxValue, ErrorMessage = "Grad je obavezan.")]
    public int CityId { get; set; }

    [RegularExpression(@"^\+?[0-9 /-]{6,20}$", ErrorMessage = "Unesite telefon od 6 do 20 znakova (cifre, razmak, / ili -, može početi sa +), npr. +387 61 123 456.")]
    public string? PhoneNumber { get; set; }
}
