namespace eBiblioteka.Api.Dtos;

public class RecommendationDto
{
    public BookListItemDto Book { get; set; } = new();
    public double Score { get; set; }

    // "Similar" = na osnovu knjiga koje je član čitao; "Popular" = popunjavanje kad nema dovoljno historije.
    public string Source { get; set; } = string.Empty;

    // Kratko objašnjenje zašto se knjiga preporučuje, spremno za prikaz u aplikaciji.
    public string Explanation { get; set; } = string.Empty;
    public List<RecommendationReasonDto> Reasons { get; set; } = new();
}

public class RecommendationReasonDto
{
    public int BookId { get; set; }
    public string BookTitle { get; set; } = string.Empty;
    public double Similarity { get; set; }
    public int CommonUsers { get; set; }
}

public class SimilarBookDto
{
    public BookListItemDto Book { get; set; } = new();
    public double Similarity { get; set; }
    public int CommonUsers { get; set; }
}
