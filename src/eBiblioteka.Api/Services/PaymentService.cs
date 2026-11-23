using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Data.Enums;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Services.PayPal;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class PaymentService : IPaymentService
{
    private readonly AppDbContext _db;
    private readonly IPayPalClient _payPal;
    private readonly PayPalOptions _options;
    private readonly INotificationService _notifications;
    private readonly ILogger<PaymentService> _logger;

    public PaymentService(
        AppDbContext db,
        IPayPalClient payPal,
        PayPalOptions options,
        INotificationService notifications,
        ILogger<PaymentService> logger)
    {
        _db = db;
        _payPal = payPal;
        _options = options;
        _notifications = notifications;
        _logger = logger;
    }

    public async Task<PaymentInitDto> StartPayPalPaymentAsync(int userId, int fineId)
    {
        // Iznos određuje server iz zakasnine u bazi; aplikacija nikada ne šalje iznos.
        var fine = await _db.Fines.Include(f => f.Loan).ThenInclude(l => l.Book)
            .FirstOrDefaultAsync(f => f.Id == fineId && f.UserId == userId)
            ?? throw new NotFoundException("Zakasnina nije pronađena.");

        if (fine.Status == FineStatus.Paid)
        {
            throw new ConflictException("Zakasnina je već plaćena.");
        }

        if (fine.Status == FineStatus.Cancelled)
        {
            throw new ConflictException("Zakasnina je stornirana i ne naplaćuje se.");
        }

        await EnsureNoOpenPaymentAsync(fineId);

        var amountEur = Math.Round(fine.Amount / LibraryRules.KmPerEur, 2, MidpointRounding.AwayFromZero);

        var payment = new Payment
        {
            FineId = fineId,
            Method = PaymentMethod.PayPal,
            Status = PaymentStatus.Pending,
            AmountKm = fine.Amount,
            AmountEur = amountEur,
            ExchangeRate = LibraryRules.KmPerEur,
            CreatedAt = DateTime.UtcNow
        };
        _db.Payments.Add(payment);
        await _db.SaveChangesAsync();

        try
        {
            var description = $"Zakasnina: {fine.Loan.Book.Title} ({fine.DaysLate} dana)";
            if (description.Length > 120)
            {
                description = description[..120];
            }

            var order = await _payPal.CreateOrderAsync(
                amountEur, $"fine-{fineId}", description, $"order-{payment.Id}");

            payment.PayPalOrderId = order.OrderId;
            await _db.SaveChangesAsync();

            _logger.LogInformation(
                "Pokrenuto plaćanje {PaymentId} za zakasninu {FineId} ({AmountKm} KM = {AmountEur} EUR), narudžba {OrderId}",
                payment.Id, fineId, fine.Amount, amountEur, order.OrderId);

            return new PaymentInitDto
            {
                PaymentId = payment.Id,
                PayPalOrderId = order.OrderId,
                ApprovalUrl = order.ApprovalUrl,
                ReturnUrl = _options.ReturnUrl,
                CancelUrl = _options.CancelUrl,
                AmountKm = fine.Amount,
                AmountEur = amountEur,
                ExchangeRate = LibraryRules.KmPerEur
            };
        }
        catch
        {
            // Narudžba nije nastala: uplata se zatvara da ne blokira novi pokušaj.
            payment.Status = PaymentStatus.Failed;
            await _db.SaveChangesAsync();
            throw;
        }
    }

    public async Task<PaymentDto> CaptureAsync(int userId, int paymentId)
    {
        var payment = await _db.Payments.Include(p => p.Fine).ThenInclude(f => f.Loan).ThenInclude(l => l.Book)
            .FirstOrDefaultAsync(p => p.Id == paymentId && p.Fine.UserId == userId)
            ?? throw new NotFoundException("Uplata nije pronađena.");

        if (payment.Method != PaymentMethod.PayPal)
        {
            throw new BadRequestException("Ova uplata nije PayPal uplata.");
        }

        // Idempotentnost: ponovljen poziv za završenu uplatu ne ponavlja nikakve efekte.
        if (payment.Status == PaymentStatus.Completed)
        {
            return await GetDtoAsync(paymentId);
        }

        if (payment.Status != PaymentStatus.Pending || payment.PayPalOrderId == null)
        {
            throw new ConflictException("Ovo plaćanje više nije aktivno. Pokrenite novo plaćanje.");
        }

        PayPalCapture capture;
        try
        {
            capture = await _payPal.CaptureOrderAsync(payment.PayPalOrderId, $"capture-{payment.Id}");
        }
        catch (PaymentProviderException ex) when (ex.Issue == "ORDER_NOT_APPROVED")
        {
            throw new ConflictException("Plaćanje nije odobreno u PayPal-u.");
        }
        catch (PaymentProviderException ex) when (ex.Issue == "INSTRUMENT_DECLINED")
        {
            await _db.Payments.Where(p => p.Id == paymentId && p.Status == PaymentStatus.Pending)
                .ExecuteUpdateAsync(s => s.SetProperty(p => p.Status, PaymentStatus.Failed));
            throw new ConflictException("PayPal je odbio uplatu (nedovoljno sredstava ili odbijen način plaćanja).");
        }

        if (payment.AmountEur != capture.AmountEur)
        {
            _logger.LogWarning(
                "Naplaćeni iznos {Captured} EUR se razlikuje od zatraženog {Requested} EUR (uplata {PaymentId})",
                capture.AmountEur, payment.AmountEur, paymentId);
        }

        var now = DateTime.UtcNow;
        await using var transaction = await _db.Database.BeginTransactionAsync();

        // Atomski prelaz Pending -> Completed: samo jedan istovremeni zahtjev ga može obaviti.
        var claimed = await _db.Payments
            .Where(p => p.Id == paymentId && p.Status == PaymentStatus.Pending)
            .ExecuteUpdateAsync(s => s
                .SetProperty(p => p.Status, PaymentStatus.Completed)
                .SetProperty(p => p.PayPalCaptureId, capture.CaptureId)
                .SetProperty(p => p.AmountEur, (decimal?)capture.AmountEur)
                .SetProperty(p => p.CompletedAt, (DateTime?)now));

        if (claimed == 0)
        {
            await transaction.RollbackAsync();
            return await GetDtoAsync(paymentId);
        }

        await _db.Fines
            .Where(f => f.Id == payment.FineId && f.Status == FineStatus.Unpaid)
            .ExecuteUpdateAsync(s => s
                .SetProperty(f => f.Status, FineStatus.Paid)
                .SetProperty(f => f.PaidAt, (DateTime?)now));

        _notifications.AddWithEmail(payment.Fine.UserId, "Zakasnina plaćena",
            $"Uplata od {capture.AmountEur:0.00} EUR ({payment.AmountKm:0.00} KM) za knjigu " +
            $"\"{payment.Fine.Loan.Book.Title}\" je uspješno primljena.");
        await _db.SaveChangesAsync();

        await transaction.CommitAsync();
        await _notifications.SendPendingEmailsAsync();

        _logger.LogInformation("Uplata {PaymentId} završena, capture {CaptureId}, {AmountEur} EUR",
            paymentId, capture.CaptureId, capture.AmountEur);

        return await GetDtoAsync(paymentId);
    }

    public async Task<PaymentDto> CancelAsync(int userId, int paymentId)
    {
        var payment = await _db.Payments
            .FirstOrDefaultAsync(p => p.Id == paymentId && p.Fine.UserId == userId)
            ?? throw new NotFoundException("Uplata nije pronađena.");

        if (payment.Status != PaymentStatus.Pending)
        {
            throw new ConflictException("Otkazati se može samo plaćanje koje je u toku.");
        }

        payment.Status = PaymentStatus.Failed;
        await _db.SaveChangesAsync();

        _logger.LogInformation("Član {UserId} je otkazao plaćanje {PaymentId}", userId, paymentId);

        return await GetDtoAsync(paymentId);
    }

    public async Task<PaymentDto> RefundAsync(int adminId, int paymentId, string reason)
    {
        var trimmedReason = reason.Trim();
        if (trimmedReason.Length < LibraryRules.MinRefundReasonLength)
        {
            throw new BadRequestException(
                $"Razlog povrata je obavezan (najmanje {LibraryRules.MinRefundReasonLength} znakova).");
        }

        var payment = await _db.Payments.Include(p => p.Fine).ThenInclude(f => f.Loan).ThenInclude(l => l.Book)
            .FirstOrDefaultAsync(p => p.Id == paymentId)
            ?? throw new NotFoundException("Uplata nije pronađena.");

        if (payment.Method != PaymentMethod.PayPal)
        {
            throw new ConflictException("Povrat je moguć samo za uplate izvršene putem PayPal-a.");
        }

        if (payment.Status == PaymentStatus.Refunded)
        {
            throw new ConflictException("Uplata je već vraćena.");
        }

        if (payment.Status != PaymentStatus.Completed || payment.PayPalCaptureId == null || payment.AmountEur == null)
        {
            throw new ConflictException("Vratiti se može samo završena uplata.");
        }

        // Vraća se iznos koji je PayPal stvarno naplatio, a ne ponovo izračunata cijena.
        var refundAmount = payment.AmountEur.Value;

        var refund = await _payPal.RefundCaptureAsync(
            payment.PayPalCaptureId, refundAmount, trimmedReason, $"refund-{payment.Id}");

        var now = DateTime.UtcNow;
        await using var transaction = await _db.Database.BeginTransactionAsync();

        var claimed = await _db.Payments
            .Where(p => p.Id == paymentId && p.Status == PaymentStatus.Completed)
            .ExecuteUpdateAsync(s => s
                .SetProperty(p => p.Status, PaymentStatus.Refunded)
                .SetProperty(p => p.RefundedAt, (DateTime?)now)
                .SetProperty(p => p.RefundedAmountEur, (decimal?)refundAmount)
                .SetProperty(p => p.RefundReason, trimmedReason)
                .SetProperty(p => p.RefundedByUserId, (int?)adminId));

        if (claimed == 0)
        {
            await transaction.RollbackAsync();
            return await GetDtoAsync(paymentId);
        }

        // Zakasnina postaje stornirana, pa ograničenje člana prestaje.
        await _db.Fines
            .Where(f => f.Id == payment.FineId && f.Status == FineStatus.Paid)
            .ExecuteUpdateAsync(s => s.SetProperty(f => f.Status, FineStatus.Cancelled));

        _notifications.AddWithEmail(payment.Fine.UserId, "Povrat uplate",
            $"Vraćeno vam je {refundAmount:0.00} EUR za zakasninu za knjigu " +
            $"\"{payment.Fine.Loan.Book.Title}\". Razlog: {trimmedReason}");
        await _db.SaveChangesAsync();

        await transaction.CommitAsync();
        await _notifications.SendPendingEmailsAsync();

        _logger.LogInformation(
            "Povrat uplate {PaymentId}: {Amount} EUR, PayPal povrat {RefundId} ({Status}), bibliotekar {AdminId}",
            paymentId, refundAmount, refund.RefundId, refund.Status, adminId);

        return await GetDtoAsync(paymentId);
    }

    public async Task<PaymentDto> GetByIdAsync(int paymentId, int actorId, bool isAdmin)
    {
        var dto = await GetDtoAsync(paymentId);

        // Član smije vidjeti samo svoje uplate; tuđa se prikazuje kao nepostojeća.
        if (!isAdmin)
        {
            var ownerId = await _db.Payments.AsNoTracking()
                .Where(p => p.Id == paymentId)
                .Select(p => p.Fine.UserId)
                .FirstAsync();
            if (ownerId != actorId)
            {
                throw new NotFoundException("Uplata nije pronađena.");
            }
        }

        return dto;
    }

    public async Task<List<PaymentDto>> GetForFineAsync(int fineId)
    {
        if (!await _db.Fines.AnyAsync(f => f.Id == fineId))
        {
            throw new NotFoundException("Zakasnina nije pronađena.");
        }

        return await Project(_db.Payments.AsNoTracking().Where(p => p.FineId == fineId)
                .OrderByDescending(p => p.CreatedAt).ThenByDescending(p => p.Id))
            .ToListAsync();
    }

    private async Task EnsureNoOpenPaymentAsync(int fineId)
    {
        var open = await _db.Payments
            .Where(p => p.FineId == fineId &&
                        (p.Status == PaymentStatus.Pending || p.Status == PaymentStatus.Completed))
            .ToListAsync();

        if (open.Any(p => p.Status == PaymentStatus.Completed))
        {
            throw new ConflictException("Za ovu zakasninu već postoji završena uplata.");
        }

        var staleBefore = DateTime.UtcNow.AddMinutes(-LibraryRules.PendingPaymentMinutes);
        var pending = open.Where(p => p.Status == PaymentStatus.Pending).ToList();

        if (pending.Any(p => p.CreatedAt >= staleBefore))
        {
            throw new ConflictException(
                "Plaćanje ove zakasnine je već pokrenuto. Dovršite ga ili ga otkažite pa pokušajte ponovo.");
        }

        // Napušteno plaćanje (aplikacija zatvorena prije potvrde) se zatvara nakon isteka vremena.
        if (pending.Count > 0)
        {
            foreach (var stale in pending)
            {
                stale.Status = PaymentStatus.Failed;
            }

            await _db.SaveChangesAsync();
        }
    }

    private async Task<PaymentDto> GetDtoAsync(int paymentId) =>
        await Project(_db.Payments.AsNoTracking().Where(p => p.Id == paymentId)).FirstOrDefaultAsync()
        ?? throw new NotFoundException("Uplata nije pronađena.");

    private IQueryable<PaymentDto> Project(IQueryable<Payment> payments) =>
        payments.Select(p => new PaymentDto
        {
            Id = p.Id,
            FineId = p.FineId,
            Method = p.Method,
            Status = p.Status,
            AmountKm = p.AmountKm,
            AmountEur = p.AmountEur,
            ExchangeRate = p.ExchangeRate,
            PayPalOrderId = p.PayPalOrderId,
            PayPalCaptureId = p.PayPalCaptureId,
            CreatedAt = p.CreatedAt,
            CompletedAt = p.CompletedAt,
            RefundedAt = p.RefundedAt,
            RefundedAmountEur = p.RefundedAmountEur,
            RefundReason = p.RefundReason,
            RefundedBy = _db.Users
                .Where(u => u.Id == p.RefundedByUserId)
                .Select(u => u.FirstName + " " + u.LastName)
                .FirstOrDefault()
        });
}
