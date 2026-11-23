namespace eBiblioteka.Api.Services.Recommender;

// Parametri preporučivača (objašnjeni u recommender-dokumentacija.md).
public static class RecommenderSettings
{
    // Težina interakcije člana i knjige: ocijenjena knjiga = ocjena / 5, a posuđena bez ocjene = neutralnih 0,6 (3 od 5).
    public const double MaxRating = 5.0;
    public const double UnratedWeight = 0.6;

    // Par knjiga ima sličnost samo ako ih je zajedno čitalo bar toliko članova (izbjegava slučajne veze).
    public const int MinCommonUsers = 2;

    // Sličnost ispod ovog praga se ne pamti.
    public const double MinSimilarity = 0.1;

    // Za svaku knjigu pamtimo najviše toliko najsličnijih knjiga.
    public const int NeighborsPerBook = 10;

    public const int DefaultCount = 5;
    public const int MaxCount = 20;
    public const int ReasonsPerRecommendation = 3;

    public static readonly TimeSpan RecalculateInterval = TimeSpan.FromHours(6);
}
