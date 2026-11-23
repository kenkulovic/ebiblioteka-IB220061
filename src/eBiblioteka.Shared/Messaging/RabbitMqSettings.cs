namespace eBiblioteka.Shared.Messaging;

public class RabbitMqSettings
{
    public string Host { get; init; } = string.Empty;
    public int Port { get; init; }
    public string User { get; init; } = string.Empty;
    public string Password { get; init; } = string.Empty;

    // Postavke dolaze isključivo iz .env fajla / varijabli okruženja.
    public static RabbitMqSettings FromEnvironment() => new()
    {
        Host = Required("RABBITMQ_HOST"),
        Port = int.Parse(Required("RABBITMQ_PORT")),
        User = Required("RABBITMQ_USER"),
        Password = Required("RABBITMQ_PASSWORD")
    };

    private static string Required(string key) =>
        Environment.GetEnvironmentVariable(key)
        ?? throw new InvalidOperationException($"Nedostaje varijabla okruženja: {key}");
}
