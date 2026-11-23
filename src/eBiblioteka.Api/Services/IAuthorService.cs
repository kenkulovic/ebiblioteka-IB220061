using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IAuthorService
{
    Task<PagedResultDto<AuthorDto>> GetAsync(PagedQueryDto query);
    Task<AuthorDto> GetByIdAsync(int id);
    Task<AuthorDto> CreateAsync(AuthorUpsertDto dto);
    Task<AuthorDto> UpdateAsync(int id, AuthorUpsertDto dto);
    Task DeleteAsync(int id);
}
