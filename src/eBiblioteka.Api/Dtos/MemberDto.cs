namespace eBiblioteka.Api.Dtos;

public class MemberDto
{
    public int Id { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string MembershipNumber { get; set; } = string.Empty;
    public int CityId { get; set; }
    public string CityName { get; set; } = string.Empty;
    public bool IsBlocked { get; set; }
    public string? BlockReason { get; set; }
    public DateTime CreatedAt { get; set; }
    public bool HasProfileImage { get; set; }
    public int ActiveLoans { get; set; }
    public int OpenReservations { get; set; }
    public int UnpaidFines { get; set; }
}
