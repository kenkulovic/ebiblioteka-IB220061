namespace eBiblioteka.Api.Data.Entities;

public class BookSimilarity
{
    public int BookId { get; set; }
    public Book Book { get; set; } = null!;

    public int SimilarBookId { get; set; }
    public Book SimilarBook { get; set; } = null!;

    public double Similarity { get; set; }
    public int CommonUsers { get; set; }
    public DateTime CalculatedAt { get; set; } = DateTime.UtcNow;
}