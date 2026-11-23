using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IReservationService
{
    Task<ReservationDetailsDto> CreateAsync(int userId, CreateReservationDto dto);
    Task<PagedResultDto<ReservationDto>> GetMineAsync(int userId, ReservationQueryDto query);
    Task<PagedResultDto<ReservationDto>> GetAllAsync(ReservationQueryDto query);
    Task<ReservationDetailsDto> GetByIdAsync(int id, int actorId, bool isAdmin);
    Task<ReservationDetailsDto> ConfirmAsync(int id, int adminId);
    Task<ReservationDetailsDto> CancelAsync(int id, int actorId, bool isAdmin, string? reason);
    Task<int> ExpireOverdueAsync();
}
