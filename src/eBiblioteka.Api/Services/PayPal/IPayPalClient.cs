namespace eBiblioteka.Api.Services.PayPal;

public record PayPalOrder(string OrderId, string ApprovalUrl);

public record PayPalCapture(string CaptureId, decimal AmountEur);

public record PayPalRefund(string RefundId, string Status);

public interface IPayPalClient
{
    // requestId čini poziv idempotentnim: ponovljen poziv s istim Id-em PayPal ne izvršava ponovo.
    Task<PayPalOrder> CreateOrderAsync(decimal amountEur, string referenceId, string description, string requestId);

    Task<PayPalCapture> CaptureOrderAsync(string orderId, string requestId);

    Task<PayPalRefund> RefundCaptureAsync(string captureId, decimal amountEur, string note, string requestId);
}
