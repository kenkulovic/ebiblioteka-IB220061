namespace eBiblioteka.Api.Dtos;

public class AuthorDto
{
    public int Id { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Biography { get; set; }
    public int CountryId { get; set; }
    public string CountryName { get; set; } = string.Empty;
    public int BookCount { get; set; }
}
