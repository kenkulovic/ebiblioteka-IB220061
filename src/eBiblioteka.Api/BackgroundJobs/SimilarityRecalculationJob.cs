using eBiblioteka.Api.Services;
using eBiblioteka.Api.Services.Recommender;

namespace eBiblioteka.Api.BackgroundJobs;

// Preračunava sličnost knjiga pri pokretanju, nakon svake nove ili izmijenjene ocjene i povremeno (za svaki slučaj).
public class SimilarityRecalculationJob : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly RecalculationTrigger _trigger;
    private readonly ILogger<SimilarityRecalculationJob> _logger;

    public SimilarityRecalculationJob(
        IServiceScopeFactory scopeFactory,
        RecalculationTrigger trigger,
        ILogger<SimilarityRecalculationJob> logger)
    {
        _scopeFactory = scopeFactory;
        _trigger = trigger;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await RecalculateAsync();

            // Čeka se zahtjev (nova ocjena) ili istek intervala, šta prije nastupi.
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
            timeout.CancelAfter(RecommenderSettings.RecalculateInterval);

            try
            {
                await _trigger.Reader.WaitToReadAsync(timeout.Token);
            }
            catch (OperationCanceledException) when (!stoppingToken.IsCancellationRequested)
            {
                continue;
            }
            catch (OperationCanceledException)
            {
                return;
            }

            // Kratko čekanje: više ocjena u nizu daje jedno preračunavanje.
            try
            {
                await Task.Delay(RecommenderSettings.RecalculateDelay, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                return;
            }

            while (_trigger.Reader.TryRead(out _))
            {
            }
        }
    }

    private async Task RecalculateAsync()
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var service = scope.ServiceProvider.GetRequiredService<IRecommendationService>();
            await service.RecalculateAsync();
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogError(ex, "Greška pri preračunavanju sličnosti knjiga");
        }
    }
}
