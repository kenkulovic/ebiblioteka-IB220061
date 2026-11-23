namespace eBiblioteka.Api.Dtos;

// Odgovor na pokretanje online plaćanja: aplikacija otvara ApprovalUrl unutar sebe (WebView),
// a kad PayPal preusmjeri na ReturnUrl/CancelUrl, presreće adresu i poziva potvrdu na serveru.
public class PaymentInitDto
{
    public int PaymentId { get; set; }
    public string PayPalOrderId { get; set; } = string.Empty;
    public string ApprovalUrl { get; set; } = string.Empty;
    public string ReturnUrl { get; set; } = string.Empty;
    public string CancelUrl { get; set; } = string.Empty;
    public decimal AmountKm { get; set; }
    public decimal AmountEur { get; set; }
    public decimal ExchangeRate { get; set; }
}
