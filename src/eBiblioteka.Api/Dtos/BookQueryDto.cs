namespace eBiblioteka.Api.Dtos;

public class BookQueryDto : PagedQueryDto
{
    public int? CategoryId { get; set; }
    public int? AuthorId { get; set; }
    // null = sve knjige, true = samo dostupne, false = samo nedostupne.
    public bool? Available { get; set; }
}
