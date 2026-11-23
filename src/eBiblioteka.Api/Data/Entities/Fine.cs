using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Data.Entities;

public class Fine
{
    public int Id { get; set; }
    public decimal Amount { get; set; }
    public int DaysLate { get; set; }
    public FineStatus Status { get; set; } = FineStatus.Unpaid;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? PaidAt { get; set; }

    public int LoanId { get; set; }
    public Loan Loan { get; set; } = null!;

    public int UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
}