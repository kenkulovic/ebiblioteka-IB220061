using System.Text.Json;
using eBiblioteka.Shared.Messaging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace eBiblioteka.Worker;

// Čita e-mail poruke iz RabbitMQ reda i šalje ih. Neuspjelo slanje se ponavlja nekoliko puta,
// a poruka koja ne uspije ni tada ide u red za ručni pregled (dead-letter).
public class EmailConsumer : BackgroundService
{
    private const int MaxAttempts = 3;
    private const string AttemptsHeader = "x-attempts";
    private static readonly TimeSpan ReconnectDelay = TimeSpan.FromSeconds(5);

    private readonly RabbitMqSettings _settings;
    private readonly IEmailSender _sender;
    private readonly ILogger<EmailConsumer> _logger;

    public EmailConsumer(RabbitMqSettings settings, IEmailSender sender, ILogger<EmailConsumer> logger)
    {
        _settings = settings;
        _sender = sender;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // RabbitMQ može biti još nedostupan pri startu ili pasti kasnije: Worker se sam ponovo spaja.
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ConsumeAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Veza s RabbitMQ-om nije uspjela, ponovni pokušaj za {Seconds}s",
                    ReconnectDelay.TotalSeconds);

                try
                {
                    await Task.Delay(ReconnectDelay, stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }
    }

    private async Task ConsumeAsync(CancellationToken stoppingToken)
    {
        var factory = new ConnectionFactory
        {
            HostName = _settings.Host,
            Port = _settings.Port,
            UserName = _settings.User,
            Password = _settings.Password
        };

        await using var connection = await factory.CreateConnectionAsync("ebiblioteka-worker", stoppingToken);
        await using var channel = await connection.CreateChannelAsync(cancellationToken: stoppingToken);

        await channel.QueueDeclareAsync(QueueNames.Email, durable: true, exclusive: false, autoDelete: false,
            cancellationToken: stoppingToken);
        await channel.QueueDeclareAsync(QueueNames.EmailDead, durable: true, exclusive: false, autoDelete: false,
            cancellationToken: stoppingToken);

        // Jedna poruka istovremeno: sljedeća se uzima tek kad je prethodna obrađena.
        await channel.BasicQosAsync(0, 1, false, stoppingToken);

        var connectionLost = new TaskCompletionSource();
        connection.ConnectionShutdownAsync += (_, _) =>
        {
            connectionLost.TrySetResult();
            return Task.CompletedTask;
        };

        var consumer = new AsyncEventingBasicConsumer(channel);
        consumer.ReceivedAsync += (_, args) => HandleAsync(channel, args, stoppingToken);
        await channel.BasicConsumeAsync(QueueNames.Email, autoAck: false, consumer, stoppingToken);

        _logger.LogInformation("Worker čeka e-mail poruke u redu {Queue}", QueueNames.Email);

        await Task.WhenAny(connectionLost.Task, Task.Delay(Timeout.Infinite, stoppingToken));
        stoppingToken.ThrowIfCancellationRequested();
        throw new InvalidOperationException("Veza s RabbitMQ-om je prekinuta.");
    }

    private async Task HandleAsync(IChannel channel, BasicDeliverEventArgs args, CancellationToken stoppingToken)
    {
        EmailMessage? message;
        try
        {
            message = JsonSerializer.Deserialize<EmailMessage>(args.Body.Span);
        }
        catch (JsonException)
        {
            message = null;
        }

        if (message == null || string.IsNullOrWhiteSpace(message.To))
        {
            // Neispravna poruka se ne može popraviti ponavljanjem.
            _logger.LogError("Neispravna e-mail poruka, premještena u {Queue}", QueueNames.EmailDead);
            await PublishAsync(channel, QueueNames.EmailDead, args.Body, args.BasicProperties, 0, stoppingToken);
            await channel.BasicAckAsync(args.DeliveryTag, false, stoppingToken);
            return;
        }

        try
        {
            await _sender.SendAsync(message, stoppingToken);
            _logger.LogInformation("E-mail poslan na {To}: {Subject}", message.To, message.Subject);
            await channel.BasicAckAsync(args.DeliveryTag, false, stoppingToken);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            var attempts = ReadAttempts(args.BasicProperties) + 1;

            if (attempts < MaxAttempts)
            {
                _logger.LogWarning(ex, "Slanje e-maila na {To} nije uspjelo (pokušaj {Attempt}/{Max}), ponavljam",
                    message.To, attempts, MaxAttempts);

                await Task.Delay(TimeSpan.FromSeconds(2 * attempts), stoppingToken);
                await PublishAsync(channel, QueueNames.Email, args.Body, args.BasicProperties, attempts, stoppingToken);
            }
            else
            {
                _logger.LogError(ex, "E-mail na {To} nije poslan ni nakon {Max} pokušaja, premješten u {Queue}",
                    message.To, MaxAttempts, QueueNames.EmailDead);

                await PublishAsync(channel, QueueNames.EmailDead, args.Body, args.BasicProperties, attempts, stoppingToken);
            }

            await channel.BasicAckAsync(args.DeliveryTag, false, stoppingToken);
        }
    }

    private static async Task PublishAsync(
        IChannel channel,
        string queue,
        ReadOnlyMemory<byte> body,
        IReadOnlyBasicProperties original,
        int attempts,
        CancellationToken cancellationToken)
    {
        var properties = new BasicProperties
        {
            Persistent = true,
            ContentType = original.ContentType,
            Headers = new Dictionary<string, object?> { [AttemptsHeader] = attempts }
        };

        await channel.BasicPublishAsync(string.Empty, queue, mandatory: false, properties, body, cancellationToken);
    }

    private static int ReadAttempts(IReadOnlyBasicProperties properties) =>
        properties.Headers != null &&
        properties.Headers.TryGetValue(AttemptsHeader, out var value) &&
        value is int attempts
            ? attempts
            : 0;
}
