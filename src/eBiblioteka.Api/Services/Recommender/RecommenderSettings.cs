namespace eBiblioteka.Api.Services.Recommender;

// Parametri preporučivača (objašnjeni u recommender-dokumentacija.md).
public static class RecommenderSettings
{
    // Par knjiga ima sličnost samo ako su ga ocijenila najmanje toliko ista člana.
    public const int MinCommonUsers = 2;

    // Predviđanje se računa iz najviše toliko najsličnijih knjiga koje je član ocijenio.
    public const int NeighborsForPrediction = 10;

    // Preporučuju se samo knjige s predviđenom ocjenom najmanje ovoliko.
    public const double MinPredictedRating = 3.5;

    // Član s manje ocjena od ovoga dobija popularne knjige umjesto personalizovanih preporuka.
    public const int MinUserRatings = 3;

    // Ocjena od koje se knjiga smatra "visoko ocijenjenom" u objašnjenju.
    public const int HighRating = 4;

    // Popularne knjige su one s najviše posudbi u posljednjih toliko dana.
    public const int PopularDays = 30;

    public const int DefaultCount = 5;
    public const int MaxCount = 5;

    public static readonly TimeSpan RecalculateInterval = TimeSpan.FromHours(6);

    // Kratko čekanje nakon nove ocjene: više ocjena u nizu daje jedno preračunavanje.
    public static readonly TimeSpan RecalculateDelay = TimeSpan.FromSeconds(2);
}
