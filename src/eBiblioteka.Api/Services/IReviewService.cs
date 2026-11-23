using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IReviewService
{
    Task<ReviewDto> CreateAsync(int userId, ReviewCreateDto dto);
    Task<ReviewDto> UpdateAsync(int userId, int reviewId, ReviewUpdateDto dto);
    Task<PagedResultDto<ReviewDto>> GetForBookAsync(int bookId, PagedQueryDto query);
    Task<PagedResultDto<ReviewDto>> GetMineAsync(int userId, PagedQueryDto query);
}
