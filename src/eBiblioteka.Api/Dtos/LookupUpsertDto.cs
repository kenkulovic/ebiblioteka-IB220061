using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class LookupUpsertDto
{
    [Required(ErrorMessage = "Naziv je obavezan.")]
    [StringLength(100, ErrorMessage = "Naziv može imati najviše 100 znakova.")]
    public string Name { get; set; } = string.Empty;
}
