using System.Text.Json;
using eBiblioteka.Shared.Messaging;
using RabbitMQ.Client;

namespace eBiblioteka.Api.Services.Email;

public sealed class RabbitMqEmailQueue : IEmailQueue, IAsyncDisposable
{
    private readonly RabbitMqSettings _settings;
    private readonly ILogger<RabbitMqEmailQueue> _logger;
    private readonly SemaphoreSlim _connectionLock = new(1, 1);
    private IConnection? _connection;

    public RabbitMqEmailQueue(RabbitMqSettings settings, ILogger<RabbitMqEmailQueue> logger)
    {
        _settings = settings;
        _logger = logger;
    }

    public async Task<bool> EnqueueAsync(EmailMessage message)
    {
        try
        {
            var connection = await GetConnectionAsync();

            // Potvrde izdavača: poziv se vraća tek kad je RabbitMQ stvarno prihvatio poruku.
            var options = new CreateChannelOptions(
                publisherConfirmationsEnabled: true,
                publisherConfirmationTrackingEnabled: true);
            await using var channel = await connection.CreateChannelAsync(options);

            await channel.QueueDeclareAsync(QueueNames.Email, durable: true, exclusive: false, autoDelete: false);

            var body = JsonSerializer.SerializeToUtf8Bytes(message);
            var properties = new BasicProperties { Persistent = true, ContentType = "application/json" };
            await channel.BasicPublishAsync(string.Empty, QueueNames.Email, mandatory: false, properties, body);

            _logger.LogInformation("E-mail za {To} stavljen u red ({Subject})", message.To, message.Subject);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "E-mail za {To} nije stavljen u red ({Subject})", message.To, message.Subject);
            return false;
        }
    }

    private async Task<IConnection> GetConnectionAsync()
    {
        if (_connection is { IsOpen: true })
        {
            return _connection;
        }

        await _connectionLock.WaitAsync();
        try
        {
            if (_connection is not { IsOpen: true })
            {
                var factory = new ConnectionFactory
                {
                    HostName = _settings.Host,
                    Port = _settings.Port,
                    UserName = _settings.User,
                    Password = _settings.Password
                };
                _connection = await factory.CreateConnectionAsync("ebiblioteka-api");
            }

            return _connection;
        }
        finally
        {
            _connectionLock.Release();
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_connection != null)
        {
            await _connection.DisposeAsync();
        }
    }
}
