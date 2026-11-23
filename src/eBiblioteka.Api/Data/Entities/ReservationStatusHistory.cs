using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Data.Entities;

public class ReservationStatusHistory
{
    public int Id { get; set; }
    public ReservationStatus? FromStatus { get; set; }
    public ReservationStatus ToStatus { get; set; }
    public DateTime ChangedAt { get; set; } = DateTime.UtcNow;
    public string? Reason { get; set; }

    public int ReservationId { get; set; }
    public Reservation Reservation { get; set; } = null!;

    public int? ChangedByUserId { get; set; }
    public ApplicationUser? ChangedByUser { get; set; }
}