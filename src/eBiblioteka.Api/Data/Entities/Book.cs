namespace eBiblioteka.Api.Data.Entities;

public class Book
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public int? PublishedYear { get; set; }
    public int? PageCount { get; set; }
    public string? Description { get; set; }
    public int TotalCopies { get; set; }
    public byte[]? CoverImage { get; set; }

    public int CategoryId { get; set; }
    public Category Category { get; set; } = null!;

    public int? PublisherId { get; set; }
    public Publisher? Publisher { get; set; }

    public ICollection<BookAuthor> BookAuthors { get; set; } = new List<BookAuthor>();
}