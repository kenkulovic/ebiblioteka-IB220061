using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class ForgotPasswordDto
{
    [Required(ErrorMessage = "E-mail je obavezan.")]
    [EmailAddress(ErrorMessage = "Unesite e-mail adresu u formatu ime@domena.ba.")]
    public string Email { get; set; } = string.Empty;
}
