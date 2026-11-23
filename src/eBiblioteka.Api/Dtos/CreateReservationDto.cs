using System.ComponentModel.DataAnnotations;

namespace eBiblioteka.Api.Dtos;

public class CreateReservationDto
{
    [Range(1, int.MaxValue, ErrorMessage = "Knjiga je obavezna.")]
    public int BookId { get; set; }
}
