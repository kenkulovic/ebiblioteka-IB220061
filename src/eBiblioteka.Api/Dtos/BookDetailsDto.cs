namespace eBiblioteka.Api.Dtos;

public class BookDetailsDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public int? PublishedYear { get; set; }
    public int? PageCount { get; set; }
    public string? Description { get; set; }
    public int TotalCopies { get; set; }
    public int AvailableCopies { get; set; }
    public int CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public int? PublisherId { get; set; }
    public string? PublisherName { get; set; }
    public List<BookAuthorDto> Authors { get; set; } = new();
    public double? AverageRating { get; set; }
    public int ReviewCount { get; set; }
    public bool HasCover { get; set; }
}

public class BookAuthorDto
{
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
}
