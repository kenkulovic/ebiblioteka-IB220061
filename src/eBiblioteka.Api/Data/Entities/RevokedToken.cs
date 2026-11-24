namespace eBiblioteka.Api.Data.Entities;

// JWT koji je poništen odjavom. Server ga odbija do isteka, pa odjava stvarno poništava token
// (a ne samo briše ga lokalno u aplikaciji). Zapisi nakon isteka tokena se brišu.
public class RevokedToken
{
    public int Id { get; set; }
    public string Jti { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
}
