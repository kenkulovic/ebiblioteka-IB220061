using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class ReviewCreateDto
{
    [Range(1, int.MaxValue, ErrorMessage = "Posudba je obavezna.")]
    public int LoanId { get; set; }

    [Range(1, 5, ErrorMessage = "Ocjena mora biti između 1 i 5.")]
    public int Rating { get; set; }

    [StringLength(500, ErrorMessage = "Komentar može imati najviše 500 znakova.")]
    public string? Comment { get; set; }
}
