namespace eBiblioteka.Api.Dtos;

public class CityDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int CountryId { get; set; }
    public string CountryName { get; set; } = string.Empty;
    // Broj zapisa koji koriste ovu stavku (stavka u upotrebi ne može se obrisati).
    public int UsageCount { get; set; }
}
