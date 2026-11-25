using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class ResetPasswordDto
{
    [Required(ErrorMessage = "E-mail je obavezan.")]
    [EmailAddress(ErrorMessage = "Unesite e-mail adresu u formatu ime@domena.ba.")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Kod je obavezan.")]
    [StringLength(20, ErrorMessage = "Unesite kod od 6 cifara iz e-maila.")]
    public string Code { get; set; } = string.Empty;

    [Required(ErrorMessage = "Nova lozinka je obavezna.")]
    [StringLength(100, MinimumLength = 4, ErrorMessage = "Nova lozinka mora imati najmanje 4 znaka.")]
    public string NewPassword { get; set; } = string.Empty;
}
