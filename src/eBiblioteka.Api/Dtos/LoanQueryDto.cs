using System.ComponentModel.DataAnnotations;
using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Dtos;

public class LoanQueryDto : PagedQueryDto
{
    public LoanFilter? Filter { get; set; }

    // Rok povrata ističe danas ili u narednih N dana (samo aktivne posudbe).
    [Range(0, 365, ErrorMessage = "Broj dana mora biti od 0 do 365.")]
    public int? DueWithinDays { get; set; }

    // Samo zapisi jednog člana (za pregled historije člana).
    public int? UserId { get; set; }
}
