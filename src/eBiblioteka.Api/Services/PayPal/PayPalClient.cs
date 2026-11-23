using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using eBiblioteka.Api.Exceptions;

namespace eBiblioteka.Api.Services.PayPal;

public class PayPalClient : IPayPalClient
{
    private const string Currency = "EUR";

    private readonly HttpClient _http;
    private readonly PayPalOptions _options;
    private readonly ILogger<PayPalClient> _logger;

    public PayPalClient(HttpClient http, PayPalOptions options, ILogger<PayPalClient> logger)
    {
        _http = http;
        _options = options;
        _logger = logger;
    }

    public async Task<PayPalOrder> CreateOrderAsync(
        decimal amountEur, string referenceId, string description, string requestId)
    {
        var body = new
        {
            intent = "CAPTURE",
            purchase_units = new[]
            {
                new
                {
                    reference_id = referenceId,
                    description,
                    amount = new { currency_code = Currency, value = Format(amountEur) }
                }
            },
            payment_source = new
            {
                paypal = new
                {
                    experience_context = new
                    {
                        brand_name = "eBiblioteka",
                        user_action = "PAY_NOW",
                        shipping_preference = "NO_SHIPPING",
                        return_url = _options.ReturnUrl,
                        cancel_url = _options.CancelUrl
                    }
                }
            }
        };

        using var json = await SendAsync(HttpMethod.Post, "/v2/checkout/orders", body, requestId);
        var root = json.RootElement;

        var orderId = root.GetProperty("id").GetString()!;
        var approvalUrl = FindLink(root, "payer-action") ?? FindLink(root, "approve")
            ?? throw new PaymentProviderException("PayPal nije vratio adresu za odobrenje plaćanja.");

        return new PayPalOrder(orderId, approvalUrl);
    }

    public async Task<PayPalCapture> CaptureOrderAsync(string orderId, string requestId)
    {
        JsonDocument json;
        try
        {
            json = await SendAsync(HttpMethod.Post, $"/v2/checkout/orders/{orderId}/capture", new { }, requestId);
        }
        catch (PaymentProviderException ex) when (ex.Issue == "ORDER_ALREADY_CAPTURED")
        {
            // Uplata je već naplaćena (npr. istovremeni zahtjev): čitamo stvarno stanje narudžbe.
            _logger.LogInformation("Narudžba {OrderId} je već naplaćena, čitam njeno stanje", orderId);
            json = await SendAsync(HttpMethod.Get, $"/v2/checkout/orders/{orderId}", null, null);
        }

        using (json)
        {
            var root = json.RootElement;
            var capture = root.GetProperty("purchase_units")[0]
                .GetProperty("payments").GetProperty("captures")[0];

            var status = capture.GetProperty("status").GetString();
            if (status != "COMPLETED")
            {
                throw new PaymentProviderException($"Uplata nije završena (status: {status}).", status);
            }

            var amount = capture.GetProperty("amount");
            if (amount.GetProperty("currency_code").GetString() != Currency)
            {
                throw new PaymentProviderException("PayPal je naplatio u neočekivanoj valuti.");
            }

            return new PayPalCapture(
                capture.GetProperty("id").GetString()!,
                decimal.Parse(amount.GetProperty("value").GetString()!, CultureInfo.InvariantCulture));
        }
    }

    public async Task<PayPalRefund> RefundCaptureAsync(
        string captureId, decimal amountEur, string note, string requestId)
    {
        var body = new
        {
            amount = new { currency_code = Currency, value = Format(amountEur) },
            note_to_payer = note.Length > 255 ? note[..255] : note
        };

        using var json = await SendAsync(HttpMethod.Post, $"/v2/payments/captures/{captureId}/refund", body, requestId);
        var root = json.RootElement;

        var status = root.GetProperty("status").GetString() ?? string.Empty;
        // PENDING je ispravan ishod: PayPal će povrat završiti sam.
        if (status != "COMPLETED" && status != "PENDING")
        {
            throw new PaymentProviderException($"Povrat nije izvršen (status: {status}).", status);
        }

        return new PayPalRefund(root.GetProperty("id").GetString()!, status);
    }

    private async Task<JsonDocument> SendAsync(HttpMethod method, string path, object? body, string? requestId)
    {
        var token = await GetAccessTokenAsync();

        using var request = new HttpRequestMessage(method, _options.BaseUrl + path);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (requestId != null)
        {
            request.Headers.Add("PayPal-Request-Id", requestId);
        }

        if (body != null)
        {
            request.Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");
        }

        return await ReadAsync(request);
    }

    private async Task<string> GetAccessTokenAsync()
    {
        if (string.IsNullOrWhiteSpace(_options.ClientId) || string.IsNullOrWhiteSpace(_options.ClientSecret))
        {
            throw new PaymentProviderException("PayPal nije konfigurisan (PAYPAL_CLIENT_ID i PAYPAL_CLIENT_SECRET).");
        }

        using var request = new HttpRequestMessage(HttpMethod.Post, _options.BaseUrl + "/v1/oauth2/token");
        var credentials = Convert.ToBase64String(
            Encoding.UTF8.GetBytes($"{_options.ClientId}:{_options.ClientSecret}"));
        request.Headers.Authorization = new AuthenticationHeaderValue("Basic", credentials);
        request.Content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "client_credentials"
        });

        using var json = await ReadAsync(request);
        return json.RootElement.GetProperty("access_token").GetString()!;
    }

    private async Task<JsonDocument> ReadAsync(HttpRequestMessage request)
    {
        HttpResponseMessage response;
        try
        {
            response = await _http.SendAsync(request);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            throw new PaymentProviderException("PayPal nije dostupan.", null, ex);
        }

        using (response)
        {
            var content = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                var issue = ExtractIssue(content);
                _logger.LogWarning("PayPal je vratio {Status} za {Method} {Path}: {Issue}",
                    (int)response.StatusCode, request.Method, request.RequestUri?.AbsolutePath, issue ?? content);
                throw new PaymentProviderException($"PayPal je odbio zahtjev ({(int)response.StatusCode}).", issue);
            }

            return JsonDocument.Parse(content);
        }
    }

    private static string? ExtractIssue(string content)
    {
        try
        {
            using var json = JsonDocument.Parse(content);
            if (json.RootElement.TryGetProperty("details", out var details) &&
                details.ValueKind == JsonValueKind.Array && details.GetArrayLength() > 0 &&
                details[0].TryGetProperty("issue", out var issue))
            {
                return issue.GetString();
            }

            return json.RootElement.TryGetProperty("name", out var name) ? name.GetString() : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static string? FindLink(JsonElement root, string rel)
    {
        if (!root.TryGetProperty("links", out var links))
        {
            return null;
        }

        foreach (var link in links.EnumerateArray())
        {
            if (link.GetProperty("rel").GetString() == rel)
            {
                return link.GetProperty("href").GetString();
            }
        }

        return null;
    }

    private static string Format(decimal amount) => amount.ToString("0.00", CultureInfo.InvariantCulture);
}
