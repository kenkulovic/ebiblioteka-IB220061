using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

// Vijest se šalje kao multipart/form-data jer uz tekst nosi i sliku.
public class NewsFormDto
{
    [Required(ErrorMessage = "Naslov je obavezan.")]
    [StringLength(100, ErrorMessage = "Naslov može imati najviše 100 znakova.")]
    public string Title { get; set; } = string.Empty;

    [Required(ErrorMessage = "Tekst je obavezan.")]
    [StringLength(2000, ErrorMessage = "Tekst može imati najviše 2000 znakova.")]
    public string Text { get; set; } = string.Empty;

    // Obavezna pri dodavanju; pri izmjeni opcionalna (bez nje ostaje stara slika).
    public IFormFile? Image { get; set; }
}
