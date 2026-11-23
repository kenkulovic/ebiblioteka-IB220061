namespace eBiblioteka.Api.Dtos;

// Izdavanje knjige: ili preuzimanje potvrđene rezervacije (ReservationId),
// ili direktno izdavanje članu na šalteru (UserId + BookId).
public class IssueLoanDto
{
    public int? ReservationId { get; set; }
    public int? UserId { get; set; }
    public int? BookId { get; set; }
}
