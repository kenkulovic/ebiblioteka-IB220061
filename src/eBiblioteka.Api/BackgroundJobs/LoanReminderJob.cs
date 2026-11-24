using eBiblioteka.Api.Services;

namespace eBiblioteka.Api.BackgroundJobs;

// Svakog sata šalje podsjetnik članovima čija posudba ističe sutra (jednom po roku).
public class LoanReminderJob : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromHours(1);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<LoanReminderJob> _logger;

    public LoanReminderJob(IServiceScopeFactory scopeFactory, ILogger<LoanReminderJob> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(Interval);

        do
        {
            try
            {
                // Servisi su Scoped, pa za svaki prolaz pravimo novi scope.
                using var scope = _scopeFactory.CreateScope();
                var service = scope.ServiceProvider.GetRequiredService<ILoanService>();
                await service.SendDueRemindersAsync();
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Greška pri slanju podsjetnika o roku povrata");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
