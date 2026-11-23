using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class PublisherUpsertDto
{
    [Required(ErrorMessage = "Naziv je obavezan.")]
    [StringLength(150, ErrorMessage = "Naziv može imati najviše 150 znakova.")]
    public string Name { get; set; } = string.Empty;

    [Range(1, int.MaxValue, ErrorMessage = "Grad je obavezan.")]
    public int CityId { get; set; }
}
