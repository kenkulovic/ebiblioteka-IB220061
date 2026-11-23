using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class RefundPaymentDto
{
    [Required(ErrorMessage = "Razlog povrata je obavezan.")]
    [StringLength(500, MinimumLength = 10, ErrorMessage = "Razlog mora imati 10 do 500 znakova.")]
    public string Reason { get; set; } = string.Empty;
}
