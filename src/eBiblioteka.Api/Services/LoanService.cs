using System.Data;
using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Data.Enums;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Helpers;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class LoanService : ILoanService
{
    private readonly AppDbContext _db;
    private readonly IMemberEligibilityService _eligibility;
    private readonly INotificationService _notifications;
    private readonly ILogger<LoanService> _logger;

    public LoanService(
        AppDbContext db,
        IMemberEligibilityService eligibility,
        INotificationService notifications,
        ILogger<LoanService> logger)
    {
        _db = db;
        _eligibility = eligibility;
        _notifications = notifications;
        _logger = logger;
    }

    public async Task<LoanDto> IssueAsync(int adminId, IssueLoanDto dto)
    {
        // Serializable: provjera dostupnosti i upis posudbe moraju biti nedjeljivi
        // da se zadnji slobodan primjerak ne može izdati dva puta.
        await using var transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable);

        Reservation? reservation = null;
        int userId;
        int bookId;

        if (dto.ReservationId.HasValue)
        {
            reservation = await _db.Reservations.FirstOrDefaultAsync(r => r.Id == dto.ReservationId.Value)
                ?? throw new NotFoundException("Rezervacija nije pronađena.");

            if (reservation.Status != ReservationStatus.Confirmed)
            {
                throw new ConflictException("Preuzeti se može samo potvrđena rezervacija.");
            }

            if (reservation.PickupDeadline != null && reservation.PickupDeadline < DateTime.UtcNow)
            {
                throw new ConflictException("Rok za preuzimanje ove rezervacije je istekao.");
            }

            userId = reservation.UserId;
            bookId = reservation.BookId;
        }
        else
        {
            if (!dto.UserId.HasValue || !dto.BookId.HasValue)
            {
                throw new BadRequestException("Potrebno je navesti rezervaciju ili člana i knjigu.");
            }

            userId = dto.UserId.Value;
            bookId = dto.BookId.Value;
        }

        var book = await _db.Books.AsNoTracking()
            .Where(b => b.Id == bookId)
            .Select(b => new { b.Title, b.TotalCopies })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Knjiga nije pronađena.");

        var restriction = await _eligibility.GetRestrictionAsync(userId);
        if (restriction != null)
        {
            throw new ConflictException($"Knjigu nije moguće izdati. {restriction}");
        }

        var activeLoans = await _db.Loans.CountAsync(l => l.UserId == userId && l.Status == LoanStatus.Active);
        if (activeLoans >= LibraryRules.MaxActiveLoans)
        {
            throw new ConflictException(
                $"Član već ima {LibraryRules.MaxActiveLoans} aktivne posudbe (najviše dozvoljeno).");
        }

        if (await _db.Loans.AnyAsync(l => l.UserId == userId && l.BookId == bookId && l.Status == LoanStatus.Active))
        {
            throw new ConflictException("Član već ima ovu knjigu posuđenu.");
        }

        if (reservation == null)
        {
            // Direktno izdavanje: član ne smije imati otvorenu rezervaciju iste knjige
            // (preuzimanje se tada evidentira kroz rezervaciju), a mora postojati slobodan primjerak.
            if (await _db.Reservations.AnyAsync(r =>
                    r.UserId == userId && r.BookId == bookId &&
                    (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed)))
            {
                throw new ConflictException(
                    "Član ima otvorenu rezervaciju ove knjige. Preuzimanje se evidentira kroz rezervaciju.");
            }

            var taken = await _db.Loans.CountAsync(l => l.BookId == bookId && l.Status == LoanStatus.Active)
                + await _db.Reservations.CountAsync(r => r.BookId == bookId && r.Status == ReservationStatus.Confirmed);
            if (book.TotalCopies - taken <= 0)
            {
                throw new ConflictException("Nema slobodnih primjeraka ove knjige.");
            }
        }

        var now = DateTime.UtcNow;
        var loan = new Loan
        {
            UserId = userId,
            BookId = bookId,
            ReservationId = reservation?.Id,
            LoanDate = now,
            DueDate = now.AddDays(LibraryRules.LoanDays),
            Status = LoanStatus.Active
        };
        _db.Loans.Add(loan);

        if (reservation != null)
        {
            reservation.Status = ReservationStatus.Completed;
            reservation.PickupDeadline = null;
            reservation.StatusHistory.Add(new ReservationStatusHistory
            {
                FromStatus = ReservationStatus.Confirmed,
                ToStatus = ReservationStatus.Completed,
                ChangedAt = now,
                ChangedByUserId = adminId,
                Reason = "Knjiga preuzeta."
            });
        }

        _notifications.Add(userId, "Knjiga posuđena",
            $"Posudili ste knjigu \"{book.Title}\". Rok povrata je {loan.DueDate:dd.MM.yyyy}.");

        await _db.SaveChangesAsync();
        await transaction.CommitAsync();

        _logger.LogInformation("Izdata knjiga {BookId} članu {UserId} (posudba {LoanId}, bibliotekar {AdminId})",
            bookId, userId, loan.Id, adminId);

        return await GetDtoAsync(loan.Id);
    }

    public async Task<LoanDto> ReturnAsync(int adminId, int loanId)
    {
        var loan = await _db.Loans.Include(l => l.Book).FirstOrDefaultAsync(l => l.Id == loanId)
            ?? throw new NotFoundException("Posudba nije pronađena.");

        if (loan.Status != LoanStatus.Active)
        {
            throw new ConflictException("Ova knjiga je već vraćena.");
        }

        var returnDate = DateTime.UtcNow;
        loan.ReturnDate = returnDate;
        loan.Status = LoanStatus.Returned;

        var (daysLate, amount) = FineCalculator.Calculate(loan.DueDate, returnDate);
        if (daysLate > 0)
        {
            _db.Fines.Add(new Fine
            {
                LoanId = loan.Id,
                UserId = loan.UserId,
                DaysLate = daysLate,
                Amount = amount,
                Status = FineStatus.Unpaid,
                CreatedAt = returnDate
            });

            _notifications.AddWithEmail(loan.UserId, "Zakasnina",
                $"Knjiga \"{loan.Book.Title}\" vraćena je s kašnjenjem od {daysLate} dana. Zakasnina: {amount:0.00} KM.");
        }
        else
        {
            _notifications.Add(loan.UserId, "Knjiga vraćena",
                $"Knjiga \"{loan.Book.Title}\" je vraćena. Možete je ocijeniti.");
        }

        // Posudba i zakasnina se snimaju zajedno, u jednoj transakciji.
        await _db.SaveChangesAsync();
        await _notifications.SendPendingEmailsAsync();

        _logger.LogInformation("Vraćena posudba {LoanId} (bibliotekar {AdminId}), kašnjenje {DaysLate} dana, zakasnina {Amount}",
            loanId, adminId, daysLate, amount);

        return await GetDtoAsync(loanId);
    }

    public async Task<LoanDto> ExtendAsync(int userId, int loanId)
    {
        // Tuđa posudba se prikazuje kao nepostojeća.
        var loan = await _db.Loans.Include(l => l.Book)
            .FirstOrDefaultAsync(l => l.Id == loanId && l.UserId == userId)
            ?? throw new NotFoundException("Posudba nije pronađena.");

        if (loan.Status != LoanStatus.Active)
        {
            throw new ConflictException("Produžiti se može samo aktivna posudba.");
        }

        if (loan.DueDate.Date < DateTime.UtcNow.Date)
        {
            throw new ConflictException("Posudba kasni i ne može se produžiti.");
        }

        if (loan.ExtensionCount >= LibraryRules.MaxExtensions)
        {
            throw new ConflictException("Posudba je već jednom produžena.");
        }

        if (await _db.Reservations.AnyAsync(r =>
                r.BookId == loan.BookId && r.UserId != userId &&
                (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed)))
        {
            throw new ConflictException("Posudba se ne može produžiti jer drugi član čeka ovu knjigu.");
        }

        loan.DueDate = loan.DueDate.AddDays(LibraryRules.ExtensionDays);
        loan.ExtensionCount++;
        // Novi rok traži novi podsjetnik.
        loan.ReminderSentAt = null;

        _notifications.Add(userId, "Posudba produžena",
            $"Posudba knjige \"{loan.Book.Title}\" produžena je do {loan.DueDate:dd.MM.yyyy}.");

        await _db.SaveChangesAsync();

        _logger.LogInformation("Produžena posudba {LoanId} (član {UserId})", loanId, userId);

        return await GetDtoAsync(loanId);
    }

    public async Task<IssueCheckDto> CheckIssueAsync(int userId, int bookId)
    {
        var totalCopies = await _db.Books.AsNoTracking()
            .Where(b => b.Id == bookId)
            .Select(b => (int?)b.TotalCopies)
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Knjiga nije pronađena.");

        var activeLoans = await _db.Loans.CountAsync(l => l.UserId == userId && l.Status == LoanStatus.Active);
        var unpaid = await _db.Fines.CountAsync(f => f.UserId == userId && f.Status == FineStatus.Unpaid);
        var taken = await _db.Loans.CountAsync(l => l.BookId == bookId && l.Status == LoanStatus.Active)
            + await _db.Reservations.CountAsync(r => r.BookId == bookId && r.Status == ReservationStatus.Confirmed);
        var available = Math.Max(0, totalCopies - taken);

        var problems = new List<string>();

        var restriction = await _eligibility.GetRestrictionAsync(userId);
        if (restriction != null)
        {
            problems.Add(restriction);
        }

        if (activeLoans >= LibraryRules.MaxActiveLoans)
        {
            problems.Add($"Član već ima {LibraryRules.MaxActiveLoans} aktivne posudbe (najviše dozvoljeno).");
        }

        if (await _db.Loans.AnyAsync(l => l.UserId == userId && l.BookId == bookId && l.Status == LoanStatus.Active))
        {
            problems.Add("Član već ima ovu knjigu posuđenu.");
        }

        if (await _db.Reservations.AnyAsync(r =>
                r.UserId == userId && r.BookId == bookId &&
                (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed)))
        {
            problems.Add("Član ima otvorenu rezervaciju ove knjige. Preuzimanje se evidentira kroz rezervaciju.");
        }

        if (available == 0)
        {
            problems.Add("Nema slobodnih primjeraka ove knjige.");
        }

        return new IssueCheckDto
        {
            ActiveLoans = activeLoans,
            MaxActiveLoans = LibraryRules.MaxActiveLoans,
            UnpaidFines = unpaid,
            AvailableCopies = available,
            CanIssue = problems.Count == 0,
            Problems = problems
        };
    }

    public async Task<ReturnPreviewDto> PreviewReturnAsync(int loanId)
    {
        var loan = await _db.Loans.AsNoTracking()
            .Where(l => l.Id == loanId)
            .Select(l => new { l.DueDate, l.Status })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Posudba nije pronađena.");

        if (loan.Status != LoanStatus.Active)
        {
            throw new ConflictException("Posudba je već vraćena.");
        }

        var returnDate = DateTime.UtcNow;
        var (daysLate, amount) = FineCalculator.Calculate(loan.DueDate, returnDate);

        return new ReturnPreviewDto
        {
            DueDate = loan.DueDate,
            ReturnDate = returnDate,
            DaysLate = daysLate,
            FineAmountKm = amount
        };
    }

    public async Task<int> SendDueRemindersAsync()
    {
        var tomorrow = DateTime.UtcNow.Date.AddDays(1);
        var due = await _db.Loans.Include(l => l.Book)
            .Where(l => l.Status == LoanStatus.Active && l.ReminderSentAt == null &&
                        l.DueDate >= tomorrow && l.DueDate < tomorrow.AddDays(1))
            .ToListAsync();

        foreach (var loan in due)
        {
            loan.ReminderSentAt = DateTime.UtcNow;
            _notifications.AddWithEmail(loan.UserId, "Rok povrata ističe sutra",
                $"Rok povrata knjige \"{loan.Book.Title}\" ističe sutra ({loan.DueDate:dd.MM.yyyy}). " +
                "Vratite je na vrijeme kako biste izbjegli zakasninu.");
        }

        if (due.Count > 0)
        {
            await _db.SaveChangesAsync();
            await _notifications.SendPendingEmailsAsync();
            _logger.LogInformation("Poslano {Count} podsjetnika o roku povrata", due.Count);
        }

        return due.Count;
    }

    public async Task<PagedResultDto<LoanDto>> GetMineAsync(int userId, LoanQueryDto query)
    {
        var loans = _db.Loans.AsNoTracking().Where(l => l.UserId == userId);
        return await FilterAndProject(loans, query, includeMemberSearch: false).ToPagedAsync(query);
    }

    public async Task<PagedResultDto<LoanDto>> GetAllAsync(LoanQueryDto query)
    {
        return await FilterAndProject(_db.Loans.AsNoTracking(), query, includeMemberSearch: true)
            .ToPagedAsync(query);
    }

    private IQueryable<LoanDto> FilterAndProject(IQueryable<Loan> loans, LoanQueryDto query, bool includeMemberSearch)
    {
        var today = DateTime.UtcNow.Date;

        if (query.UserId.HasValue)
        {
            loans = loans.Where(l => l.UserId == query.UserId.Value);
        }

        if (query.Filter.HasValue)
        {
            loans = query.Filter.Value switch
            {
                LoanFilter.Active => loans.Where(l => l.Status == LoanStatus.Active),
                LoanFilter.Overdue => loans.Where(l => l.Status == LoanStatus.Active && l.DueDate.Date < today),
                LoanFilter.Returned => loans.Where(l => l.Status == LoanStatus.Returned),
                _ => loans
            };
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            loans = includeMemberSearch
                ? loans.Where(l =>
                    l.Book.Title.Contains(search) ||
                    (l.User.FirstName + " " + l.User.LastName).Contains(search) ||
                    l.User.MembershipNumber.Contains(search))
                : loans.Where(l => l.Book.Title.Contains(search));
        }

        return Project(loans.OrderByDescending(l => l.LoanDate).ThenByDescending(l => l.Id), today);
    }

    private IQueryable<LoanDto> Project(IQueryable<Loan> loans, DateTime today) =>
        loans.Select(l => new LoanDto
        {
            Id = l.Id,
            LoanDate = l.LoanDate,
            DueDate = l.DueDate,
            ReturnDate = l.ReturnDate,
            ExtensionCount = l.ExtensionCount,
            Status = l.Status,
            IsOverdue = l.Status == LoanStatus.Active && l.DueDate.Date < today,
            UserId = l.UserId,
            UserFullName = l.User.FirstName + " " + l.User.LastName,
            MembershipNumber = l.User.MembershipNumber,
            BookId = l.BookId,
            BookTitle = l.Book.Title,
            BookHasCover = l.Book.CoverImage != null,
            FineId = _db.Fines.Where(f => f.LoanId == l.Id).Select(f => (int?)f.Id).FirstOrDefault(),
            HasReview = _db.Reviews.Any(r => r.LoanId == l.Id)
        });

    private async Task<LoanDto> GetDtoAsync(int id) =>
        await Project(_db.Loans.AsNoTracking().Where(l => l.Id == id), DateTime.UtcNow.Date)
            .FirstOrDefaultAsync()
        ?? throw new NotFoundException("Posudba nije pronađena.");
}
