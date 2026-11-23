namespace eBiblioteka.Api.Exceptions;

// Greška servisa za plaćanje (PayPal): nedostupan, odbio zahtjev ili nije konfigurisan.
public class PaymentProviderException : Exception
{
    public PaymentProviderException(string message, string? issue = null, Exception? inner = null)
        : base(message, inner)
    {
        Issue = issue;
    }

    // Šifra problema koju vraća PayPal (npr. ORDER_NOT_APPROVED).
    public string? Issue { get; }
}
