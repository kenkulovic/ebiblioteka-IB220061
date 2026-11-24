using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class UpdateProfileDto
{
    [Required(ErrorMessage = "Ime je obavezno.")]
    [StringLength(50, ErrorMessage = "Ime može imati najviše 50 znakova.")]
    public string FirstName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Prezime je obavezno.")]
    [StringLength(50, ErrorMessage = "Prezime može imati najviše 50 znakova.")]
    public string LastName { get; set; } = string.Empty;

    [Required(ErrorMessage = "E-mail je obavezan.")]
    [EmailAddress(ErrorMessage = "E-mail adresa nije ispravna.")]
    [StringLength(100, ErrorMessage = "E-mail može imati najviše 100 znakova.")]
    public string Email { get; set; } = string.Empty;

    [Range(1, int.MaxValue, ErrorMessage = "Grad je obavezan.")]
    public int CityId { get; set; }

    [RegularExpression(@"^\+?[0-9 /-]{6,20}$", ErrorMessage = "Broj telefona nije ispravan.")]
    public string? PhoneNumber { get; set; }
}
