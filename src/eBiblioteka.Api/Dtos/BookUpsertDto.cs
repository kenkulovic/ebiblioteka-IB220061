using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class BookUpsertDto
{
    [Required(ErrorMessage = "Naslov je obavezan.")]
    [StringLength(200, ErrorMessage = "Naslov može imati najviše 200 znakova.")]
    public string Title { get; set; } = string.Empty;

    [Range(1000, 2100, ErrorMessage = "Godina izdanja nije ispravna.")]
    public int? PublishedYear { get; set; }

    [Range(1, 20000, ErrorMessage = "Broj stranica nije ispravan.")]
    public int? PageCount { get; set; }

    [StringLength(2000, ErrorMessage = "Opis može imati najviše 2000 znakova.")]
    public string? Description { get; set; }

    [Range(1, 1000, ErrorMessage = "Broj primjeraka mora biti između 1 i 1000.")]
    public int TotalCopies { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Kategorija je obavezna.")]
    public int CategoryId { get; set; }

    public int? PublisherId { get; set; }

    [Required(ErrorMessage = "Knjiga mora imati barem jednog autora.")]
    [MinLength(1, ErrorMessage = "Knjiga mora imati barem jednog autora.")]
    public List<int> AuthorIds { get; set; } = new();
}
