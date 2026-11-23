using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Dtos;

public class ReportQueryDto
{
    public DateOnly? From { get; set; }
    public DateOnly? To { get; set; }
}

public class CountItemDto
{
    public string Name { get; set; } = string.Empty;
    public int Count { get; set; }
}

public class LoanReportDto
{
    public DateOnly From { get; set; }
    public DateOnly To { get; set; }
    public int TotalLoans { get; set; }
    public int Returned { get; set; }
    public int Active { get; set; }
    public int OverdueNow { get; set; }
    public double? AverageLoanDays { get; set; }
    public List<CountItemDto> TopBooks { get; set; } = new();
    public List<CountItemDto> ByCategory { get; set; } = new();
    public List<LoanReportItemDto> Items { get; set; } = new();
    public bool ItemsTruncated { get; set; }
}

public class LoanReportItemDto
{
    public DateTime LoanDate { get; set; }
    public string Member { get; set; } = string.Empty;
    public string Book { get; set; } = string.Empty;
    public DateTime DueDate { get; set; }
    public DateTime? ReturnDate { get; set; }
    public bool IsOverdue { get; set; }
}

public class FineReportDto
{
    public DateOnly From { get; set; }
    public DateOnly To { get; set; }
    public int TotalFines { get; set; }
    public decimal TotalAmountKm { get; set; }
    public FineStatusTotalDto Unpaid { get; set; } = new();
    public FineStatusTotalDto Paid { get; set; } = new();
    public FineStatusTotalDto Cancelled { get; set; } = new();
    public decimal PaidPayPalKm { get; set; }
    public decimal PaidCounterKm { get; set; }
    public int RefundedCount { get; set; }
    public decimal RefundedEur { get; set; }
    public List<FineReportItemDto> Items { get; set; } = new();
    public bool ItemsTruncated { get; set; }
}

public class FineStatusTotalDto
{
    public int Count { get; set; }
    public decimal AmountKm { get; set; }
}

public class FineReportItemDto
{
    public DateTime CreatedAt { get; set; }
    public string Member { get; set; } = string.Empty;
    public string Book { get; set; } = string.Empty;
    public int DaysLate { get; set; }
    public decimal AmountKm { get; set; }
    public FineStatus Status { get; set; }
    public PaymentMethod? PaymentMethod { get; set; }
}
