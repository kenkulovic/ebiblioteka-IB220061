namespace eBiblioteka.Api.Dtos;

public class RecommendationDto
{
    public BookListItemDto Book { get; set; } = new();
    // Predviđena ocjena koju bi član dao knjizi (1-5); za popularne knjige je 0.
    public double Score { get; set; }

    // "Similar" = predviđanje iz članovih ocjena; "Popular" = član ima premalo ocjena ili nema dovoljno dobrog predviđanja.
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

    // Ocjena koju je član dao toj knjizi.
    public int UserRating { get; set; }
}

public class SimilarBookDto
{
    public BookListItemDto Book { get; set; } = new();
    public double Similarity { get; set; }
    public int CommonUsers { get; set; }
}
