using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Enums;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Reports;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class ReportService : IReportService
{
    private const int MaxItems = 200;
    private const int MaxRangeDays = 366;
    private const int DefaultRangeDays = 30;

    private readonly AppDbContext _db;

    public ReportService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<LoanReportDto> GetLoanReportAsync(ReportQueryDto query)
    {
        var (from, to, fromUtc, toUtc) = NormalizePeriod(query);

        var loans = _db.Loans.AsNoTracking().Where(l => l.LoanDate >= fromUtc && l.LoanDate < toUtc);
        var today = DateTime.UtcNow.Date;

        var total = await loans.CountAsync();
        var returned = await loans.CountAsync(l => l.Status == LoanStatus.Returned);
        var overdue = await loans.CountAsync(l => l.Status == LoanStatus.Active && l.DueDate.Date < today);

        var averageDays = await loans
            .Where(l => l.Status == LoanStatus.Returned && l.ReturnDate != null)
            .AverageAsync(l => (double?)EF.Functions.DateDiffDay(l.LoanDate, l.ReturnDate!.Value));

        var topBooks = await loans
            .GroupBy(l => l.Book.Title)
            .Select(g => new CountItemDto { Name = g.Key, Count = g.Count() })
            .OrderByDescending(x => x.Count)
            .ThenBy(x => x.Name)
            .Take(5)
            .ToListAsync();

        var byCategory = await loans
            .GroupBy(l => l.Book.Category.Name)
            .Select(g => new CountItemDto { Name = g.Key, Count = g.Count() })
            .OrderByDescending(x => x.Count)
            .ThenBy(x => x.Name)
            .ToListAsync();

        var items = await loans
            .OrderByDescending(l => l.LoanDate)
            .ThenByDescending(l => l.Id)
            .Take(MaxItems + 1)
            .Select(l => new LoanReportItemDto
            {
                LoanDate = l.LoanDate,
                Member = l.User.FirstName + " " + l.User.LastName,
                Book = l.Book.Title,
                DueDate = l.DueDate,
                ReturnDate = l.ReturnDate,
                IsOverdue = l.Status == LoanStatus.Active && l.DueDate.Date < today
            })
            .ToListAsync();

        return new LoanReportDto
        {
            From = from,
            To = to,
            TotalLoans = total,
            Returned = returned,
            Active = total - returned,
            OverdueNow = overdue,
            AverageLoanDays = averageDays.HasValue ? Math.Round(averageDays.Value, 1) : null,
            TopBooks = topBooks,
            ByCategory = byCategory,
            Items = items.Take(MaxItems).ToList(),
            ItemsTruncated = items.Count > MaxItems
        };
    }

    public async Task<FineReportDto> GetFineReportAsync(ReportQueryDto query)
    {
        var (from, to, fromUtc, toUtc) = NormalizePeriod(query);

        var fines = _db.Fines.AsNoTracking().Where(f => f.CreatedAt >= fromUtc && f.CreatedAt < toUtc);
        var payments = _db.Payments.AsNoTracking()
            .Where(p => p.Fine.CreatedAt >= fromUtc && p.Fine.CreatedAt < toUtc);

        var byStatus = await fines
            .GroupBy(f => f.Status)
            .Select(g => new { Status = g.Key, Count = g.Count(), Sum = g.Sum(f => f.Amount) })
            .ToListAsync();

        FineStatusTotalDto Total(FineStatus status)
        {
            var row = byStatus.FirstOrDefault(r => r.Status == status);
            return new FineStatusTotalDto { Count = row?.Count ?? 0, AmountKm = row?.Sum ?? 0m };
        }

        // Plaćeno se računa samo za završene uplate; vraćene uplate se prikazuju zasebno.
        var paidPayPal = await payments
            .Where(p => p.Method == PaymentMethod.PayPal && p.Status == PaymentStatus.Completed)
            .SumAsync(p => p.AmountKm);
        var paidCounter = await payments
            .Where(p => p.Method == PaymentMethod.Counter && p.Status == PaymentStatus.Completed)
            .SumAsync(p => p.AmountKm);
        var refunded = payments.Where(p => p.Status == PaymentStatus.Refunded);

        var items = await fines
            .OrderByDescending(f => f.CreatedAt)
            .ThenByDescending(f => f.Id)
            .Take(MaxItems + 1)
            .Select(f => new FineReportItemDto
            {
                CreatedAt = f.CreatedAt,
                Member = f.User.FirstName + " " + f.User.LastName,
                Book = f.Loan.Book.Title,
                DaysLate = f.DaysLate,
                AmountKm = f.Amount,
                Status = f.Status,
                PaymentMethod = f.Payments
                    .OrderByDescending(p => p.CreatedAt)
                    .Select(p => (PaymentMethod?)p.Method)
                    .FirstOrDefault()
            })
            .ToListAsync();

        return new FineReportDto
        {
            From = from,
            To = to,
            TotalFines = byStatus.Sum(r => r.Count),
            TotalAmountKm = byStatus.Sum(r => r.Sum),
            Unpaid = Total(FineStatus.Unpaid),
            Paid = Total(FineStatus.Paid),
            Cancelled = Total(FineStatus.Cancelled),
            PaidPayPalKm = paidPayPal,
            PaidCounterKm = paidCounter,
            RefundedCount = await refunded.CountAsync(),
            RefundedEur = await refunded.SumAsync(p => p.RefundedAmountEur ?? 0m),
            Items = items.Take(MaxItems).ToList(),
            ItemsTruncated = items.Count > MaxItems
        };
    }

    public async Task<byte[]> GetLoanReportPdfAsync(ReportQueryDto query, int adminId)
    {
        var report = await GetLoanReportAsync(query);
        return ReportPdfGenerator.Loans(report, await GetAdminNameAsync(adminId));
    }

    public async Task<byte[]> GetFineReportPdfAsync(ReportQueryDto query, int adminId)
    {
        var report = await GetFineReportAsync(query);
        return ReportPdfGenerator.Fines(report, await GetAdminNameAsync(adminId));
    }

    private async Task<string> GetAdminNameAsync(int adminId) =>
        await _db.Users.AsNoTracking()
            .Where(u => u.Id == adminId)
            .Select(u => u.FirstName + " " + u.LastName)
            .FirstOrDefaultAsync()
        ?? "—";

    // Zadani period je posljednjih 30 dana; najviše godinu dana da izvještaj ostane čitljiv.
    private static (DateOnly From, DateOnly To, DateTime FromUtc, DateTime ToUtcExclusive) NormalizePeriod(
        ReportQueryDto query)
    {
        var to = query.To ?? DateOnly.FromDateTime(DateTime.UtcNow);
        var from = query.From ?? to.AddDays(-(DefaultRangeDays - 1));

        if (from > to)
        {
            throw new BadRequestException("Početni datum ne može biti poslije krajnjeg.");
        }

        if (to.DayNumber - from.DayNumber > MaxRangeDays)
        {
            throw new BadRequestException("Period izvještaja može biti najviše godinu dana.");
        }

        return (
            from,
            to,
            from.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc),
            to.AddDays(1).ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc));
    }
}
