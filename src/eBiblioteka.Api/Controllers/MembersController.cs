using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/members")]
[Authorize]
public class MembersController : ControllerBase
{
    private readonly IMemberService _service;

    public MembersController(IMemberService service)
    {
        _service = service;
    }

    [HttpGet]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<PagedResultDto<MemberDto>>> Get([FromQuery] MemberQueryDto query)
        => Ok(await _service.GetAsync(query));

    [HttpGet("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<MemberDto>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id));

    [HttpGet("me")]
    public async Task<ActionResult<MemberDto>> GetMe()
        => Ok(await _service.GetByIdAsync(User.GetUserId()));

    [HttpPut("me")]
    public async Task<ActionResult<MemberDto>> UpdateMe(UpdateProfileDto dto)
        => Ok(await _service.UpdateProfileAsync(User.GetUserId(), dto));

    [HttpPost("me/change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordDto dto)
    {
        await _service.ChangePasswordAsync(User.GetUserId(), dto);
        return NoContent();
    }

    [HttpGet("{id:int}/image")]
    public async Task<IActionResult> GetImage(int id)
    {
        var image = await _service.GetImageAsync(id, User.GetUserId(), User.IsAdministrator());
        return File(image.Data, image.ContentType);
    }

    [HttpPut("me/image")]
    public async Task<IActionResult> SetImage(IFormFile file)
    {
        await using var stream = file.OpenReadStream();
        await _service.SetImageAsync(User.GetUserId(), stream, file.Length);
        return NoContent();
    }

    [HttpDelete("me/image")]
    public async Task<IActionResult> RemoveImage()
    {
        await _service.RemoveImageAsync(User.GetUserId());
        return NoContent();
    }

    [HttpPost("{id:int}/block")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<MemberDto>> Block(int id, BlockMemberDto dto)
        => Ok(await _service.BlockAsync(User.GetUserId(), id, dto.Reason));

    [HttpPost("{id:int}/unblock")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<MemberDto>> Unblock(int id)
        => Ok(await _service.UnblockAsync(User.GetUserId(), id));
}
