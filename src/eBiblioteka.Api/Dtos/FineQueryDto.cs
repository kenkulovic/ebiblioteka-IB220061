using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Dtos;

public class FineQueryDto : PagedQueryDto
{
    public FineStatus? Status { get; set; }

    // Samo zapisi jednog člana (za pregled historije člana).
    public int? UserId { get; set; }
}
