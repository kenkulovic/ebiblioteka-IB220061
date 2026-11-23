namespace eBiblioteka.Api.Constants;

// Poslovna pravila biblioteke (poglavlje 3 prijedloga teme).
public static class LibraryRules
{
    public const int LoanDays = 14;
    public const int ExtensionDays = 7;
    public const int MaxExtensions = 1;
    public const int MaxActiveLoans = 3;
    public const int MaxOpenReservations = 3;
    public const int PickupDays = 3;
    public const int MinReasonLength = 5;

    public const decimal FinePerDay = 0.50m;
    public const decimal MaxFine = 15.00m;
}
