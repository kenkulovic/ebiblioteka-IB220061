namespace eBiblioteka.Api.Services.PayPal;

public class PayPalOptions
{
    public string ClientId { get; init; } = string.Empty;
    public string ClientSecret { get; init; } = string.Empty;
    public string BaseUrl { get; init; } = string.Empty;
    public string ReturnUrl { get; init; } = string.Empty;
    public string CancelUrl { get; init; } = string.Empty;

    // Sve postavke dolaze isključivo iz .env fajla / varijabli okruženja.
    // Ključevi mogu biti prazni dok se ne unesu pravi sandbox podaci; tada plaćanje vraća jasnu grešku.
    public static PayPalOptions FromEnvironment() => new()
    {
        ClientId = Environment.GetEnvironmentVariable("PAYPAL_CLIENT_ID") ?? string.Empty,
        ClientSecret = Environment.GetEnvironmentVariable("PAYPAL_CLIENT_SECRET") ?? string.Empty,
        BaseUrl = Required("PAYPAL_BASE_URL").TrimEnd('/'),
        ReturnUrl = Required("PAYPAL_RETURN_URL"),
        CancelUrl = Required("PAYPAL_CANCEL_URL")
    };

    private static string Required(string key) =>
        Environment.GetEnvironmentVariable(key)
        ?? throw new InvalidOperationException($"Nedostaje varijabla okruženja: {key}");
}
