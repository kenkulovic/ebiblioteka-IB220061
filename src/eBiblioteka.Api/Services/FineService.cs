using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Data.Enums;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class FineService : IFineService
{
    private readonly AppDbContext _db;
    private readonly INotificationService _notifications;
    private readonly ILogger<FineService> _logger;

    public FineService(AppDbContext db, INotificationService notifications, ILogger<FineService> logger)
    {
        _db = db;
        _notifications = notifications;
        _logger = logger;
    }

    public async Task<PagedResultDto<FineDto>> GetAllAsync(FineQueryDto query)
    {
        return await FilterAndProject(_db.Fines.AsNoTracking(), query, includeMemberSearch: true)
            .ToPagedAsync(query);
    }

    public async Task<PagedResultDto<FineDto>> GetMineAsync(int userId, FineQueryDto query)
    {
        var fines = _db.Fines.AsNoTracking().Where(f => f.UserId == userId);
        return await FilterAndProject(fines, query, includeMemberSearch: false).ToPagedAsync(query);
    }

    public async Task<FineDto> PayAtCounterAsync(int adminId, int fineId)
    {
        var fine = await _db.Fines.Include(f => f.Loan).ThenInclude(l => l.Book)
            .FirstOrDefaultAsync(f => f.Id == fineId)
            ?? throw new NotFoundException("Zakasnina nije pronađena.");

        if (fine.Status == FineStatus.Paid)
        {
            throw new ConflictException("Zakasnina je već plaćena.");
        }

        if (fine.Status == FineStatus.Cancelled)
        {
            throw new ConflictException("Zakasnina je stornirana i ne naplaćuje se.");
        }

        // Ako je član već pokrenuo online plaćanje, šalterska uplata bi dovela do dvostruke naplate.
        if (await _db.Payments.AnyAsync(p => p.FineId == fineId && p.Status == PaymentStatus.Pending))
        {
            throw new ConflictException("Za ovu zakasninu je u toku online plaćanje.");
        }

        var now = DateTime.UtcNow;
        fine.Status = FineStatus.Paid;
        fine.PaidAt = now;

        _db.Payments.Add(new Payment
        {
            FineId = fine.Id,
            Method = PaymentMethod.Counter,
            Status = PaymentStatus.Completed,
            AmountKm = fine.Amount,
            CreatedAt = now,
            CompletedAt = now
        });

        _notifications.AddWithEmail(fine.UserId, "Zakasnina plaćena",
            $"Evidentirana je uplata zakasnine od {fine.Amount:0.00} KM za knjigu \"{fine.Loan.Book.Title}\".");

        // Zakasnina i uplata se snimaju zajedno.
        await _db.SaveChangesAsync();
        await _notifications.SendPendingEmailsAsync();

        _logger.LogInformation("Zakasnina {FineId} plaćena na šalteru (bibliotekar {AdminId})", fineId, adminId);

        return await FilterAndProject(_db.Fines.AsNoTracking().Where(f => f.Id == fineId),
                new FineQueryDto(), includeMemberSearch: false)
            .FirstAsync();
    }

    private static IQueryable<FineDto> FilterAndProject(
        IQueryable<Fine> fines,
        FineQueryDto query,
        bool includeMemberSearch)
    {
        if (query.Status.HasValue)
        {
            fines = fines.Where(f => f.Status == query.Status.Value);
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            fines = includeMemberSearch
                ? fines.Where(f =>
                    f.Loan.Book.Title.Contains(search) ||
                    (f.User.FirstName + " " + f.User.LastName).Contains(search) ||
                    f.User.MembershipNumber.Contains(search))
                : fines.Where(f => f.Loan.Book.Title.Contains(search));
        }

        return fines
            .OrderByDescending(f => f.CreatedAt)
            .ThenByDescending(f => f.Id)
            .Select(f => new FineDto
            {
                Id = f.Id,
                Amount = f.Amount,
                DaysLate = f.DaysLate,
                Status = f.Status,
                CreatedAt = f.CreatedAt,
                PaidAt = f.PaidAt,
                LoanId = f.LoanId,
                BookId = f.Loan.BookId,
                BookTitle = f.Loan.Book.Title,
                BookHasCover = f.Loan.Book.CoverImage != null,
                UserId = f.UserId,
                UserFullName = f.User.FirstName + " " + f.User.LastName,
                PendingPaymentId = f.Payments
                    .Where(p => p.Status == PaymentStatus.Pending)
                    .Select(p => (int?)p.Id)
                    .FirstOrDefault(),
                PaymentMethod = f.Payments
                    .Where(p => p.Status == PaymentStatus.Completed)
                    .OrderByDescending(p => p.CreatedAt)
                    .Select(p => (PaymentMethod?)p.Method)
                    .FirstOrDefault()
            });
    }
}
