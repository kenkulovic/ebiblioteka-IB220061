using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IRecommendationService
{
    Task<List<RecommendationDto>> GetForUserAsync(int userId, int count);
    Task<List<SimilarBookDto>> GetSimilarBooksAsync(int bookId, int count);

    // Preračunava tabelu sličnosti knjiga iz posudbi i ocjena; vraća broj zapisanih parova.
    Task<int> RecalculateAsync();
}
