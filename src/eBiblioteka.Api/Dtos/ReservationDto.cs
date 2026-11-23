using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Dtos;

public class ReservationDto
{
    public int Id { get; set; }
    public ReservationStatus Status { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? PickupDeadline { get; set; }
    public int UserId { get; set; }
    public string UserFullName { get; set; } = string.Empty;
    public string MembershipNumber { get; set; } = string.Empty;
    public int BookId { get; set; }
    public string BookTitle { get; set; } = string.Empty;
    public bool BookHasCover { get; set; }
}

public class ReservationDetailsDto : ReservationDto
{
    public List<ReservationHistoryDto> History { get; set; } = new();
}

public class ReservationHistoryDto
{
    public ReservationStatus? FromStatus { get; set; }
    public ReservationStatus ToStatus { get; set; }
    public DateTime ChangedAt { get; set; }
    public string? Reason { get; set; }
    public string ChangedBy { get; set; } = string.Empty;
}
