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
    public const int MinReasonLength = 10;

    public const int MinRefundReasonLength = 10;
    public const int PendingPaymentMinutes = 30;

    // PayPal ne podržava konvertibilnu marku, pa se naplata vrši u eurima po fiksnom kursu.
    public const decimal KmPerEur = 1.95583m;

    public const decimal FinePerDay = 0.50m;
    public const decimal MaxFine = 15.00m;
}
