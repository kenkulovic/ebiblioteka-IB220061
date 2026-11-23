using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class ChangePasswordDto
{
    [Required(ErrorMessage = "Trenutna lozinka je obavezna.")]
    public string CurrentPassword { get; set; } = string.Empty;

    [Required(ErrorMessage = "Nova lozinka je obavezna.")]
    [StringLength(100, MinimumLength = 4, ErrorMessage = "Nova lozinka mora imati najmanje 4 znaka.")]
    public string NewPassword { get; set; } = string.Empty;
}
