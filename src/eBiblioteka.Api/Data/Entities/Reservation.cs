using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Data.Entities;

public class Reservation
{
    public int Id { get; set; }
    public ReservationStatus Status { get; set; } = ReservationStatus.Pending;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? PickupDeadline { get; set; }

    public int UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public int BookId { get; set; }
    public Book Book { get; set; } = null!;

    public ICollection<ReservationStatusHistory> StatusHistory { get; set; } = new List<ReservationStatusHistory>();
}