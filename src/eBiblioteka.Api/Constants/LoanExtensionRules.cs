using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Constants;

/// <summary>
/// Pravilo produženja posudbe na jednom mjestu: koristi ga i akcija produženja i prikaz posudbe (razlog zašto je dugme onemogućeno).
/// </summary>
public static class LoanExtensionRules
{
    public static string? GetBlockedReason(
        LoanStatus status, DateTime dueDate, int extensionCount, bool otherMemberWaiting, DateTime today)
    {
        if (status != LoanStatus.Active)
        {
            return "Produžiti se može samo aktivna posudba.";
        }

        if (dueDate.Date < today.Date)
        {
            return "Posudba kasni i ne može se produžiti.";
        }

        if (extensionCount >= LibraryRules.MaxExtensions)
        {
            return "Posudba je već jednom produžena.";
        }

        if (otherMemberWaiting)
        {
            return "Posudba se ne može produžiti jer drugi član čeka ovu knjigu.";
        }

        return null;
    }
}
