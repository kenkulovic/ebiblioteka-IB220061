namespace eBiblioteka.Api.Dtos;

// Rezultat provjere pravila prije izdavanja knjige (prikazuje se bibliotekaru u formi).
public class IssueCheckDto
{
    public int ActiveLoans { get; set; }
    public int MaxActiveLoans { get; set; }
    public int UnpaidFines { get; set; }
    public int AvailableCopies { get; set; }
    public bool CanIssue { get; set; }
    public List<string> Problems { get; set; } = new();
}

// Pregled povrata: rok, današnji datum povrata, dani kašnjenja i zakasnina koja će biti obračunata.
public class ReturnPreviewDto
{
    public DateTime DueDate { get; set; }
    public DateTime ReturnDate { get; set; }
    public int DaysLate { get; set; }
    public decimal FineAmountKm { get; set; }
}

// Može li član rezervisati knjigu; ako ne, razlog se prikazuje uz onemogućeno dugme.
public class ReserveCheckDto
{
    public bool CanReserve { get; set; }
    public string? Reason { get; set; }
}
