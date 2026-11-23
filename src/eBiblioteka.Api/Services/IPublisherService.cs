using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IPublisherService
{
    Task<PagedResultDto<PublisherDto>> GetAsync(PagedQueryDto query);
    Task<PublisherDto> GetByIdAsync(int id);
    Task<PublisherDto> CreateAsync(PublisherUpsertDto dto);
    Task<PublisherDto> UpdateAsync(int id, PublisherUpsertDto dto);
    Task DeleteAsync(int id);
}
