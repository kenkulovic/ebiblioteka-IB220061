using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class ForgotPasswordDto
{
    [Required(ErrorMessage = "E-mail je obavezan.")]
    [EmailAddress(ErrorMessage = "E-mail adresa nije ispravna.")]
    public string Email { get; set; } = string.Empty;
}
