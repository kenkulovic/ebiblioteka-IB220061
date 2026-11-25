using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Dtos;

public class FineDto
{
    public int Id { get; set; }
    public decimal Amount { get; set; }
    // Iznos koji bi PayPal naplatio (fiksni kurs).
    public decimal AmountEur => Math.Round(Amount / LibraryRules.KmPerEur, 2, MidpointRounding.AwayFromZero);
    public int DaysLate { get; set; }
    public FineStatus Status { get; set; }
    public bool IsPaid => Status == FineStatus.Paid;
    public DateTime CreatedAt { get; set; }
    public DateTime? PaidAt { get; set; }
    public int LoanId { get; set; }
    public int BookId { get; set; }
    public string BookTitle { get; set; } = string.Empty;
    public bool BookHasCover { get; set; }
    public int UserId { get; set; }
    public string UserFullName { get; set; } = string.Empty;
    public PaymentMethod? PaymentMethod { get; set; }
    public bool HasPendingPayment => PendingPaymentId.HasValue;

    // Uplata koja je pokrenuta, ali nije završena; član je može otkazati.
    public int? PendingPaymentId { get; set; }
}
