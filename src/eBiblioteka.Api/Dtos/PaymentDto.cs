using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Dtos;

public class PaymentDto
{
    public int Id { get; set; }
    public int FineId { get; set; }
    public PaymentMethod Method { get; set; }
    public PaymentStatus Status { get; set; }
    public decimal AmountKm { get; set; }
    public decimal? AmountEur { get; set; }
    public decimal? ExchangeRate { get; set; }
    public string? PayPalOrderId { get; set; }
    public string? PayPalCaptureId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public DateTime? RefundedAt { get; set; }
    public decimal? RefundedAmountEur { get; set; }
    public string? RefundReason { get; set; }
    public string? RefundedBy { get; set; }
}
