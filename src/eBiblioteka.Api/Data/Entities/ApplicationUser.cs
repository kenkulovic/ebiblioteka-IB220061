using Microsoft.AspNetCore.Identity;

namespace eBiblioteka.Api.Data.Entities;

public class ApplicationUser : IdentityUser<int>
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string MembershipNumber { get; set; } = string.Empty;
    public byte[]? ProfileImage { get; set; }
    public bool IsBlocked { get; set; }
    public string? BlockReason { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public int CityId { get; set; }
    public City City { get; set; } = null!;
}