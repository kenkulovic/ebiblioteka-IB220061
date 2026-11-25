using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Dtos;

public class LoanQueryDto : PagedQueryDto
{
    public LoanFilter? Filter { get; set; }

    // Samo posudbe čiji je rok povrata na odabrani datum ili prije njega.
    public DateOnly? DueTo { get; set; }

    // Samo zapisi jednog člana (za pregled historije člana).
    public int? UserId { get; set; }
}
