using System.Data;
using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Data.Enums;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class ReservationService : IReservationService
{
    private readonly AppDbContext _db;
    private readonly IMemberEligibilityService _eligibility;
    private readonly INotificationService _notifications;
    private readonly ILogger<ReservationService> _logger;

    public ReservationService(
        AppDbContext db,
        IMemberEligibilityService eligibility,
        INotificationService notifications,
        ILogger<ReservationService> logger)
    {
        _db = db;
        _eligibility = eligibility;
        _notifications = notifications;
        _logger = logger;
    }

    public async Task<ReservationDetailsDto> CreateAsync(int userId, CreateReservationDto dto)
    {
        var restriction = await _eligibility.GetRestrictionAsync(userId);
        if (restriction != null)
        {
            throw new ForbiddenException(restriction);
        }

        if (!await _db.Books.AnyAsync(b => b.Id == dto.BookId))
        {
            throw new NotFoundException("Knjiga nije pronađena.");
        }

        if (await _db.Loans.AnyAsync(l =>
                l.UserId == userId && l.BookId == dto.BookId && l.Status == LoanStatus.Active))
        {
            throw new ConflictException("Ovu knjigu već imate posuđenu.");
        }

        if (await _db.Reservations.AnyAsync(r =>
                r.UserId == userId && r.BookId == dto.BookId &&
                (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed)))
        {
            throw new ConflictException("Već imate otvorenu rezervaciju za ovu knjigu.");
        }

        var openCount = await _db.Reservations.CountAsync(r =>
            r.UserId == userId &&
            (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed));
        if (openCount >= LibraryRules.MaxOpenReservations)
        {
            throw new ConflictException(
                $"Možete imati najviše {LibraryRules.MaxOpenReservations} otvorene rezervacije.");
        }

        var reservation = new Reservation
        {
            UserId = userId,
            BookId = dto.BookId,
            Status = ReservationStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };
        AddHistory(reservation, null, ReservationStatus.Pending, userId, null);

        _db.Reservations.Add(reservation);
        await _db.SaveChangesAsync();

        _logger.LogInformation("Član {UserId} je rezervisao knjigu {BookId} (rezervacija {ReservationId})",
            userId, dto.BookId, reservation.Id);

        return await GetDetailsAsync(reservation.Id);
    }

    public async Task<ReserveCheckDto> CheckAsync(int userId, int bookId)
    {
        if (!await _db.Books.AnyAsync(b => b.Id == bookId))
        {
            throw new NotFoundException("Knjiga nije pronađena.");
        }

        var restriction = await _eligibility.GetRestrictionAsync(userId);
        if (restriction != null)
        {
            var hasUnpaidFine = await _db.Fines.AnyAsync(f => f.UserId == userId && f.Status == FineStatus.Unpaid);
            return new ReserveCheckDto { Reason = restriction, HasUnpaidFine = hasUnpaidFine };
        }

        if (await _db.Loans.AnyAsync(l => l.UserId == userId && l.BookId == bookId && l.Status == LoanStatus.Active))
        {
            return new ReserveCheckDto { Reason = "Ovu knjigu već imate posuđenu." };
        }

        if (await _db.Reservations.AnyAsync(r =>
                r.UserId == userId && r.BookId == bookId &&
                (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed)))
        {
            return new ReserveCheckDto { Reason = "Već imate otvorenu rezervaciju za ovu knjigu." };
        }

        var openCount = await _db.Reservations.CountAsync(r =>
            r.UserId == userId &&
            (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed));
        if (openCount >= LibraryRules.MaxOpenReservations)
        {
            return new ReserveCheckDto
            {
                Reason = $"Možete imati najviše {LibraryRules.MaxOpenReservations} otvorene rezervacije."
            };
        }

        return new ReserveCheckDto { CanReserve = true };
    }

    public async Task<PagedResultDto<ReservationDto>> GetMineAsync(int userId, ReservationQueryDto query)
    {
        var reservations = _db.Reservations.AsNoTracking().Where(r => r.UserId == userId);
        return await FilterAndProject(reservations, query, includeMemberSearch: false).ToPagedAsync(query);
    }

    public async Task<PagedResultDto<ReservationDto>> GetAllAsync(ReservationQueryDto query)
    {
        return await FilterAndProject(_db.Reservations.AsNoTracking(), query, includeMemberSearch: true)
            .ToPagedAsync(query);
    }

    public async Task<ReservationDetailsDto> GetByIdAsync(int id, int actorId, bool isAdmin)
    {
        var details = await GetDetailsAsync(id);

        // Član smije vidjeti samo svoje rezervacije; tuđa se prikazuje kao nepostojeća.
        if (!isAdmin && details.UserId != actorId)
        {
            throw new NotFoundException("Rezervacija nije pronađena.");
        }

        return details;
    }

    public async Task<ReservationDetailsDto> ConfirmAsync(int id, int adminId)
    {
        // Serializable: provjera dostupnosti i potvrda moraju biti jedna nedjeljiva cjelina,
        // inače bi dva bibliotekara istovremeno mogla potvrditi zadnji slobodan primjerak.
        await using var transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable);

        var reservation = await _db.Reservations.FirstOrDefaultAsync(r => r.Id == id)
            ?? throw new NotFoundException("Rezervacija nije pronađena.");

        if (reservation.Status != ReservationStatus.Pending)
        {
            throw new ConflictException("Potvrditi se može samo rezervacija koja je na čekanju.");
        }

        var restriction = await _eligibility.GetRestrictionAsync(reservation.UserId);
        if (restriction != null)
        {
            throw new ConflictException($"Rezervaciju nije moguće potvrditi. {restriction}");
        }

        var hasOlderPending = await _db.Reservations.AnyAsync(r =>
            r.BookId == reservation.BookId &&
            r.Status == ReservationStatus.Pending &&
            (r.CreatedAt < reservation.CreatedAt ||
             (r.CreatedAt == reservation.CreatedAt && r.Id < reservation.Id)));
        if (hasOlderPending)
        {
            throw new ConflictException(
                "Za isti naslov postoji starija rezervacija na čekanju, koja se mora potvrditi prva.");
        }

        var book = await _db.Books.AsNoTracking()
            .Where(b => b.Id == reservation.BookId)
            .Select(b => new { b.Title, b.TotalCopies })
            .FirstAsync();

        var taken = await _db.Loans.CountAsync(l => l.BookId == reservation.BookId && l.Status == LoanStatus.Active)
            + await _db.Reservations.CountAsync(r => r.BookId == reservation.BookId && r.Status == ReservationStatus.Confirmed);
        if (book.TotalCopies - taken <= 0)
        {
            throw new ConflictException("Nema slobodnih primjeraka ove knjige.");
        }

        reservation.Status = ReservationStatus.Confirmed;
        reservation.PickupDeadline = DateTime.UtcNow.AddDays(LibraryRules.PickupDays);
        AddHistory(reservation, ReservationStatus.Pending, ReservationStatus.Confirmed, adminId, null);

        _notifications.AddWithEmail(reservation.UserId, "Rezervacija potvrđena",
            $"Knjiga \"{book.Title}\" čeka vas do {reservation.PickupDeadline:dd.MM.yyyy}.");

        await _db.SaveChangesAsync();
        await transaction.CommitAsync();
        await _notifications.SendPendingEmailsAsync();

        _logger.LogInformation("Rezervacija {ReservationId} potvrđena (bibliotekar {AdminId})", id, adminId);

        return await GetDetailsAsync(id);
    }

    public async Task<ReservationDetailsDto> CancelAsync(int id, int actorId, bool isAdmin, string? reason)
    {
        var reservation = await _db.Reservations.Include(r => r.Book).FirstOrDefaultAsync(r => r.Id == id)
            ?? throw new NotFoundException("Rezervacija nije pronađena.");

        // Član može otkazati samo svoju rezervaciju; tuđa se prikazuje kao nepostojeća.
        if (!isAdmin && reservation.UserId != actorId)
        {
            throw new NotFoundException("Rezervacija nije pronađena.");
        }

        if (!IsOpen(reservation.Status))
        {
            throw new ConflictException("Otkazati se može samo rezervacija na čekanju ili potvrđena rezervacija.");
        }

        var trimmedReason = string.IsNullOrWhiteSpace(reason) ? null : reason.Trim();
        if (isAdmin && (trimmedReason == null || trimmedReason.Length < LibraryRules.MinReasonLength))
        {
            throw new BadRequestException(
                $"Razlog je obavezan (najmanje {LibraryRules.MinReasonLength} znakova).");
        }

        var from = reservation.Status;
        reservation.Status = ReservationStatus.Cancelled;
        reservation.PickupDeadline = null;
        AddHistory(reservation, from, ReservationStatus.Cancelled, actorId,
            trimmedReason ?? "Otkazao član.");

        if (isAdmin)
        {
            _notifications.AddWithEmail(reservation.UserId, "Rezervacija otkazana",
                $"Rezervacija knjige \"{reservation.Book.Title}\" je otkazana. Razlog: {trimmedReason}");
        }

        await _db.SaveChangesAsync();
        await _notifications.SendPendingEmailsAsync();

        _logger.LogInformation("Rezervacija {ReservationId} otkazana (korisnik {ActorId}, admin: {IsAdmin})",
            id, actorId, isAdmin);

        return await GetDetailsAsync(id);
    }

    public async Task<int> ExpireOverdueAsync()
    {
        var now = DateTime.UtcNow;
        var expired = await _db.Reservations
            .Include(r => r.Book)
            .Where(r => r.Status == ReservationStatus.Confirmed &&
                        r.PickupDeadline != null && r.PickupDeadline < now)
            .ToListAsync();

        foreach (var reservation in expired)
        {
            reservation.Status = ReservationStatus.Cancelled;
            reservation.PickupDeadline = null;
            // Izvršilac je null: promjenu je napravio sistem.
            AddHistory(reservation, ReservationStatus.Confirmed, ReservationStatus.Cancelled, null,
                "Istekao je rok preuzimanja.");

            _notifications.Add(reservation.UserId, "Rezervacija istekla",
                $"Rok za preuzimanje knjige \"{reservation.Book.Title}\" je istekao, pa je rezervacija otkazana.");
        }

        if (expired.Count > 0)
        {
            await _db.SaveChangesAsync();
            _logger.LogInformation("Istekao rok preuzimanja za {Count} rezervacija", expired.Count);
        }

        return expired.Count;
    }

    private static bool IsOpen(ReservationStatus status) =>
        status == ReservationStatus.Pending || status == ReservationStatus.Confirmed;

    private static void AddHistory(
        Reservation reservation,
        ReservationStatus? from,
        ReservationStatus to,
        int? changedByUserId,
        string? reason)
    {
        reservation.StatusHistory.Add(new ReservationStatusHistory
        {
            FromStatus = from,
            ToStatus = to,
            ChangedAt = DateTime.UtcNow,
            ChangedByUserId = changedByUserId,
            Reason = reason
        });
    }

    private static IQueryable<ReservationDto> FilterAndProject(
        IQueryable<Reservation> reservations,
        ReservationQueryDto query,
        bool includeMemberSearch)
    {
        if (query.UserId.HasValue)
        {
            reservations = reservations.Where(r => r.UserId == query.UserId.Value);
        }

        if (query.Status.HasValue)
        {
            reservations = reservations.Where(r => r.Status == query.Status.Value);
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            reservations = includeMemberSearch
                ? reservations.Where(r =>
                    r.Book.Title.Contains(search) ||
                    (r.User.FirstName + " " + r.User.LastName).Contains(search) ||
                    r.User.MembershipNumber.Contains(search))
                : reservations.Where(r => r.Book.Title.Contains(search));
        }

        return reservations
            .OrderByDescending(r => r.CreatedAt)
            .ThenByDescending(r => r.Id)
            .Select(r => new ReservationDto
            {
                Id = r.Id,
                Status = r.Status,
                CreatedAt = r.CreatedAt,
                PickupDeadline = r.PickupDeadline,
                UserId = r.UserId,
                UserFullName = r.User.FirstName + " " + r.User.LastName,
                MembershipNumber = r.User.MembershipNumber,
                BookId = r.BookId,
                BookTitle = r.Book.Title,
                BookHasCover = r.Book.CoverImage != null
            });
    }

    private async Task<ReservationDetailsDto> GetDetailsAsync(int id)
    {
        var details = await _db.Reservations.AsNoTracking()
            .Where(r => r.Id == id)
            .Select(r => new ReservationDetailsDto
            {
                Id = r.Id,
                Status = r.Status,
                CreatedAt = r.CreatedAt,
                PickupDeadline = r.PickupDeadline,
                UserId = r.UserId,
                UserFullName = r.User.FirstName + " " + r.User.LastName,
                MembershipNumber = r.User.MembershipNumber,
                BookId = r.BookId,
                BookTitle = r.Book.Title,
                BookHasCover = r.Book.CoverImage != null
            })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Rezervacija nije pronađena.");

        details.History = await _db.ReservationStatusHistory.AsNoTracking()
            .Where(h => h.ReservationId == id)
            .OrderBy(h => h.ChangedAt)
            .ThenBy(h => h.Id)
            .Select(h => new ReservationHistoryDto
            {
                FromStatus = h.FromStatus,
                ToStatus = h.ToStatus,
                ChangedAt = h.ChangedAt,
                Reason = h.Reason,
                ChangedBy = h.ChangedByUser != null
                    ? h.ChangedByUser.FirstName + " " + h.ChangedByUser.LastName
                    : "Sistem"
            })
            .ToListAsync();

        return details;
    }
}
