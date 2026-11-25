using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Dtos;

public class LoanDto
{
    public int Id { get; set; }
    public DateTime LoanDate { get; set; }
    public DateTime DueDate { get; set; }
    public DateTime? ReturnDate { get; set; }
    public int ExtensionCount { get; set; }
    public LoanStatus Status { get; set; }
    public bool IsOverdue { get; set; }
    public int DaysOverdue => IsOverdue ? (DateTime.UtcNow.Date - DueDate.Date).Days : 0;
    public int UserId { get; set; }
    public string UserFullName { get; set; } = string.Empty;
    public string MembershipNumber { get; set; } = string.Empty;
    public int BookId { get; set; }
    public string BookTitle { get; set; } = string.Empty;
    public bool BookHasCover { get; set; }
    public int? FineId { get; set; }
    public decimal? FineAmount { get; set; }
    public FineStatus? FineStatus { get; set; }
    public bool HasReview { get; set; }

    // Drugi član čeka istu knjigu (rezervacija na čekanju ili potvrđena).
    public bool OtherMemberWaiting { get; set; }

    // Za aktivnu posudbu: razlog zašto se ne može produžiti (null kad je produženje moguće).
    public string? ExtensionBlockedReason => Status != LoanStatus.Active
        ? null
        : LoanExtensionRules.GetBlockedReason(Status, DueDate, ExtensionCount, OtherMemberWaiting, DateTime.UtcNow);
}
