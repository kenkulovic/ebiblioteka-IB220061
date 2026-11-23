using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class BlockMemberDto
{
    [Required(ErrorMessage = "Razlog blokiranja je obavezan.")]
    [StringLength(500, MinimumLength = 5, ErrorMessage = "Razlog mora imati 5 do 500 znakova.")]
    public string Reason { get; set; } = string.Empty;
}
