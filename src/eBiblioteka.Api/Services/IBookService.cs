using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IBookService
{
    Task<PagedResultDto<BookListItemDto>> GetAsync(BookQueryDto query);
    Task<BookDetailsDto> GetByIdAsync(int id);
    Task<BookDetailsDto> CreateAsync(BookUpsertDto dto);
    Task<BookDetailsDto> UpdateAsync(int id, BookUpsertDto dto);
    Task DeleteAsync(int id);
    Task<BookCoverDto> GetCoverAsync(int id);
    Task SetCoverAsync(int id, Stream content, long length);
    Task RemoveCoverAsync(int id);
}
