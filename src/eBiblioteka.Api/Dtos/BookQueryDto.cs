namespace eBiblioteka.Api.Dtos;

public class BookQueryDto : PagedQueryDto
{
    public int? CategoryId { get; set; }
    public int? AuthorId { get; set; }
    public bool OnlyAvailable { get; set; }
}
