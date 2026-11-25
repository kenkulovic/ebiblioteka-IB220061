using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface INewsService
{
    Task<PagedResultDto<NewsDto>> GetAsync(PagedQueryDto query);
    Task<NewsDto> GetByIdAsync(int id);
    Task<NewsDto> CreateAsync(int adminId, string title, string text, Stream image, long imageLength);
    Task<NewsDto> UpdateAsync(int id, string title, string text, Stream? image, long imageLength);
    Task DeleteAsync(int id);
    Task<ImageDto> GetImageAsync(int id);
}
