using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface ICategoryService
{
    Task<PagedResultDto<LookupDto>> GetAsync(PagedQueryDto query);
    Task<LookupDto> GetByIdAsync(int id);
    Task<LookupDto> CreateAsync(LookupUpsertDto dto);
    Task<LookupDto> UpdateAsync(int id, LookupUpsertDto dto);
    Task DeleteAsync(int id);
}
