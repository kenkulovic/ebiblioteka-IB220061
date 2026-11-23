using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface ICityService
{
    Task<PagedResultDto<CityDto>> GetAsync(PagedQueryDto query, int? countryId);
    Task<CityDto> GetByIdAsync(int id);
    Task<CityDto> CreateAsync(CityUpsertDto dto);
    Task<CityDto> UpdateAsync(int id, CityUpsertDto dto);
    Task DeleteAsync(int id);
}
