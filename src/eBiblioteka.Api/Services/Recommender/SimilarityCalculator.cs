namespace eBiblioteka.Api.Services.Recommender;

// Interakcija člana s knjigom: Weight je u rasponu (0, 1].
public record Interaction(int UserId, int BookId, double Weight);

public record BookSimilarityResult(int BookId, int SimilarBookId, double Similarity, int CommonUsers);

// Item-based collaborative filtering: sličnost dvije knjige je kosinusna sličnost njihovih
// vektora (jedan element po članu): sličnost(A, B) = (suma w(u,A) * w(u,B)) / (|A| * |B|).
public static class SimilarityCalculator
{
    public static double WeightOf(double? averageRating) =>
        averageRating.HasValue
            ? averageRating.Value / RecommenderSettings.MaxRating
            : RecommenderSettings.UnratedWeight;

    public static List<BookSimilarityResult> Calculate(IReadOnlyCollection<Interaction> interactions)
    {
        var squares = new Dictionary<int, double>();
        var dots = new Dictionary<(int, int), double>();
        var commons = new Dictionary<(int, int), int>();

        // Po članu: njegove knjige se uparuju svaka sa svakom. Složenost je zbir kvadrata broja
        // knjiga po članu, što je za biblioteku (nekoliko desetina knjiga po članu) zanemarivo.
        foreach (var userInteractions in interactions.GroupBy(i => i.UserId))
        {
            var items = userInteractions.OrderBy(i => i.BookId).ToList();

            for (var x = 0; x < items.Count; x++)
            {
                squares[items[x].BookId] = squares.GetValueOrDefault(items[x].BookId) + items[x].Weight * items[x].Weight;

                for (var y = x + 1; y < items.Count; y++)
                {
                    var key = (items[x].BookId, items[y].BookId);
                    dots[key] = dots.GetValueOrDefault(key) + items[x].Weight * items[y].Weight;
                    commons[key] = commons.GetValueOrDefault(key) + 1;
                }
            }
        }

        var all = new List<BookSimilarityResult>();
        foreach (var ((a, b), dot) in dots)
        {
            var common = commons[(a, b)];
            if (common < RecommenderSettings.MinCommonUsers)
            {
                continue;
            }

            var similarity = dot / (Math.Sqrt(squares[a]) * Math.Sqrt(squares[b]));
            if (similarity < RecommenderSettings.MinSimilarity)
            {
                continue;
            }

            // Sličnost je simetrična, pa se pamti u oba smjera.
            all.Add(new BookSimilarityResult(a, b, similarity, common));
            all.Add(new BookSimilarityResult(b, a, similarity, common));
        }

        return all
            .GroupBy(r => r.BookId)
            .SelectMany(g => g
                .OrderByDescending(r => r.Similarity)
                .ThenByDescending(r => r.CommonUsers)
                .ThenBy(r => r.SimilarBookId)
                .Take(RecommenderSettings.NeighborsPerBook))
            .ToList();
    }
}
