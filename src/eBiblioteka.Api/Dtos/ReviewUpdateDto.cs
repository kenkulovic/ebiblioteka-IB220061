using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class ReviewUpdateDto
{
    [Range(1, 5, ErrorMessage = "Ocjena mora biti između 1 i 5.")]
    public int Rating { get; set; }

    [StringLength(500, ErrorMessage = "Komentar može imati najviše 500 znakova.")]
    public string? Comment { get; set; }
}
