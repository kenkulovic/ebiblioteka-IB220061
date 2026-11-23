using eBiblioteka.Api.Services;

namespace eBiblioteka.Api.BackgroundJobs;

// Povremeno otkazuje potvrđene rezervacije kojima je istekao rok preuzimanja (izvršilac: Sistem).
public class ReservationExpirationJob : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(5);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<ReservationExpirationJob> _logger;

    public ReservationExpirationJob(IServiceScopeFactory scopeFactory, ILogger<ReservationExpirationJob> logger)
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
                var service = scope.ServiceProvider.GetRequiredService<IReservationService>();
                await service.ExpireOverdueAsync();
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Greška pri otkazivanju isteklih rezervacija");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
