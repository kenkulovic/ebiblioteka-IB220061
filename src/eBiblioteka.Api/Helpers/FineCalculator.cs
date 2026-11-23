using eBiblioteka.Api.Constants;

namespace eBiblioteka.Api.Helpers;

public static class FineCalculator
{
    // Zakasnina: 0,50 KM za svaki dan kašnjenja, najviše 15,00 KM po posudbi.
    // Dani se računaju po kalendarskim datumima: povrat na dan roka nema zakasninu.
    public static (int DaysLate, decimal Amount) Calculate(DateTime dueDate, DateTime returnDate)
    {
        var daysLate = Math.Max(0, (returnDate.Date - dueDate.Date).Days);
        var amount = Math.Min(daysLate * LibraryRules.FinePerDay, LibraryRules.MaxFine);
        return (daysLate, amount);
    }
}
