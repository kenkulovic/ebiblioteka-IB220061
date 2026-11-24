namespace eBiblioteka.Api.Services.Recommender;

// Ocjena (1-5) koju je član dao knjizi; za više ocjena iste knjige uzima se prosjek.
public record Rating(int UserId, int BookId, double Value);

public record BookSimilarityResult(int BookId, int SimilarBookId, double Similarity, int CommonUsers);

// Item-based collaborative filtering s prilagođenom kosinusnom sličnošću (adjusted cosine similarity).
//
// Od svake ocjene oduzme se prosječna ocjena tog člana (da blagi i strogi ocjenjivači budu uporedivi), a zatim se
// sličnost knjiga A i B računa nad članovima koji su ocijenili obje:
//
//   sličnost(A, B) =  Σ (r(u,A) - prosjek(u)) · (r(u,B) - prosjek(u))
//                    ─────────────────────────────────────────────────
//                      √Σ (r(u,A) - prosjek(u))²  ·  √Σ (r(u,B) - prosjek(u))²
public static class SimilarityCalculator
{
    public static List<BookSimilarityResult> Calculate(IReadOnlyCollection<Rating> ratings)
    {
        var userMeans = ratings
            .GroupBy(r => r.UserId)
            .ToDictionary(g => g.Key, g => g.Average(r => r.Value));

        // Za svaku knjigu: član -> ocjena umanjena za prosjek tog člana.
        var centered = ratings
            .GroupBy(r => r.BookId)
            .ToDictionary(g => g.Key, g => g.ToDictionary(r => r.UserId, r => r.Value - userMeans[r.UserId]));

        var bookIds = centered.Keys.Order().ToList();
        var results = new List<BookSimilarityResult>();

        for (var x = 0; x < bookIds.Count; x++)
        {
            for (var y = x + 1; y < bookIds.Count; y++)
            {
                var a = centered[bookIds[x]];
                var b = centered[bookIds[y]];

                double dot = 0, normA = 0, normB = 0;
                var common = 0;

                foreach (var (userId, valueA) in a)
                {
                    if (!b.TryGetValue(userId, out var valueB))
                    {
                        continue;
                    }

                    dot += valueA * valueB;
                    normA += valueA * valueA;
                    normB += valueB * valueB;
                    common++;
                }

                if (common < RecommenderSettings.MinCommonUsers || normA == 0 || normB == 0)
                {
                    continue;
                }

                var similarity = dot / (Math.Sqrt(normA) * Math.Sqrt(normB));

                // Za predviđanje se koriste samo pozitivne sličnosti, pa se samo one pamte.
                if (similarity <= 0)
                {
                    continue;
                }

                // Sličnost je simetrična, pa se pamti u oba smjera.
                results.Add(new BookSimilarityResult(bookIds[x], bookIds[y], similarity, common));
                results.Add(new BookSimilarityResult(bookIds[y], bookIds[x], similarity, common));
            }
        }

        return results;
    }
}
