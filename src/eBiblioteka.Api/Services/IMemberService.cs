using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IMemberService
{
    Task<PagedResultDto<MemberDto>> GetAsync(MemberQueryDto query);
    Task<MemberDto> GetByIdAsync(int id);
    Task<MemberDto> UpdateProfileAsync(int userId, UpdateProfileDto dto);
    Task ChangePasswordAsync(int userId, ChangePasswordDto dto);
    Task<ImageDto> GetImageAsync(int id, int actorId, bool isAdmin);
    Task SetImageAsync(int userId, Stream content, long length);
    Task RemoveImageAsync(int userId);
    Task<MemberDto> BlockAsync(int adminId, int memberId, string reason);
    Task<MemberDto> UnblockAsync(int adminId, int memberId);
}
