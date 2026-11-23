using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IFineService
{
    Task<PagedResultDto<FineDto>> GetAllAsync(FineQueryDto query);
    Task<PagedResultDto<FineDto>> GetMineAsync(int userId, FineQueryDto query);
    Task<FineDto> PayAtCounterAsync(int adminId, int fineId);
}
