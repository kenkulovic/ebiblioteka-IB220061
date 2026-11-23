using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class CancelReservationDto
{
    [StringLength(500, ErrorMessage = "Razlog može imati najviše 500 znakova.")]
    public string? Reason { get; set; }
}
