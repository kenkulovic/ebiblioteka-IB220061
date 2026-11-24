namespace eBiblioteka.Api.Dtos;

public class PublisherDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int CityId { get; set; }
    public string CityName { get; set; } = string.Empty;
    // Broj zapisa koji koriste ovu stavku (stavka u upotrebi ne može se obrisati).
    public int UsageCount { get; set; }
}
