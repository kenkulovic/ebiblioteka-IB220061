using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class AuthorUpsertDto
{
    [Required(ErrorMessage = "Ime je obavezno.")]
    [StringLength(50, ErrorMessage = "Ime može imati najviše 50 znakova.")]
    public string FirstName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Prezime je obavezno.")]
    [StringLength(50, ErrorMessage = "Prezime može imati najviše 50 znakova.")]
    public string LastName { get; set; } = string.Empty;

    [StringLength(1000, ErrorMessage = "Biografija može imati najviše 1000 znakova.")]
    public string? Biography { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Država je obavezna.")]
    public int CountryId { get; set; }
}
