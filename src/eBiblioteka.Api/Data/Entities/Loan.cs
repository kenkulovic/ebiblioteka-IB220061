using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Data.Entities;

public class Loan
{
    public int Id { get; set; }
    public DateTime LoanDate { get; set; }
    public DateTime DueDate { get; set; }
    public DateTime? ReturnDate { get; set; }
    public int ExtensionCount { get; set; }

    // Kad je poslan podsjetnik da rok povrata ističe sutra (null = nije poslan).
    public DateTime? ReminderSentAt { get; set; }
    public LoanStatus Status { get; set; } = LoanStatus.Active;

    public int UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public int BookId { get; set; }
    public Book Book { get; set; } = null!;

    public int? ReservationId { get; set; }
    public Reservation? Reservation { get; set; }
}