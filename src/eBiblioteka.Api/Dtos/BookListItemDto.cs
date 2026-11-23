namespace eBiblioteka.Api.Dtos;

public class BookListItemDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public int? PublishedYear { get; set; }
    public int CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public List<string> Authors { get; set; } = new();
    public int TotalCopies { get; set; }
    public int AvailableCopies { get; set; }
    public double? AverageRating { get; set; }
    public bool HasCover { get; set; }
}
