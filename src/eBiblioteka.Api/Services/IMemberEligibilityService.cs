namespace eBiblioteka.Api.Services;

public interface IMemberEligibilityService
{
    // Vraća razlog zbog kojeg član ne može rezervisati ni posuđivati, ili null ako može.
    Task<string?> GetRestrictionAsync(int userId);
}
