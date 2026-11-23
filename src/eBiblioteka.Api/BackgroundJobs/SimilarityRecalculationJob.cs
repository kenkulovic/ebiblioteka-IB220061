using eBiblioteka.Api.Services;
using eBiblioteka.Api.Services.Recommender;

namespace eBiblioteka.Api.BackgroundJobs;

// Preračunava sličnost knjiga pri pokretanju aplikacije, a zatim periodično.
public class SimilarityRecalculationJob : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<SimilarityRecalculationJob> _logger;

    public SimilarityRecalculationJob(IServiceScopeFactory scopeFactory, ILogger<SimilarityRecalculationJob> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(RecommenderSettings.RecalculateInterval);

        do
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
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
