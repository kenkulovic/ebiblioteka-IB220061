using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Dtos;

public class ReservationQueryDto : PagedQueryDto
{
    public ReservationStatus? Status { get; set; }

    // Samo zapisi jednog člana (za pregled historije člana).
    public int? UserId { get; set; }
}
