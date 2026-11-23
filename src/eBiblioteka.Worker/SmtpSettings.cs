namespace eBiblioteka.Worker;

public class SmtpSettings
{
    public string Host { get; init; } = string.Empty;
    public int Port { get; init; }
    public string From { get; init; } = string.Empty;

    // Opcionalno, za pravi SMTP server (u razvoju se koristi Mailpit bez prijave).
    public string? User { get; init; }
    public string? Password { get; init; }
    public bool UseStartTls { get; init; }

    public static SmtpSettings FromEnvironment() => new()
    {
        Host = Required("SMTP_HOST"),
        Port = int.Parse(Required("SMTP_PORT")),
        From = Required("SMTP_FROM"),
        User = Optional("SMTP_USER"),
        Password = Optional("SMTP_PASSWORD"),
        UseStartTls = string.Equals(Optional("SMTP_STARTTLS"), "true", StringComparison.OrdinalIgnoreCase)
    };

    private static string Required(string key) =>
        Environment.GetEnvironmentVariable(key)
        ?? throw new InvalidOperationException($"Nedostaje varijabla okruženja: {key}");

    private static string? Optional(string key)
    {
        var value = Environment.GetEnvironmentVariable(key);
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }
}
