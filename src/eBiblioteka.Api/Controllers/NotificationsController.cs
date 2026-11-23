using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/notifications")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _service;

    public NotificationsController(INotificationService service)
    {
        _service = service;
    }

    [HttpGet("mine")]
    public async Task<ActionResult<PagedResultDto<NotificationDto>>> GetMine([FromQuery] NotificationQueryDto query)
        => Ok(await _service.GetMineAsync(User.GetUserId(), query));

    [HttpGet("unread-count")]
    public async Task<ActionResult<int>> GetUnreadCount()
        => Ok(await _service.GetUnreadCountAsync(User.GetUserId()));

    [HttpPost("{id:int}/read")]
    public async Task<IActionResult> MarkAsRead(int id)
    {
        await _service.MarkAsReadAsync(User.GetUserId(), id);
        return NoContent();
    }

    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllAsRead()
    {
        await _service.MarkAllAsReadAsync(User.GetUserId());
        return NoContent();
    }
}
