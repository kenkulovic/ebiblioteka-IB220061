using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/reservations")]
[Authorize]
public class ReservationsController : ControllerBase
{
    private readonly IReservationService _service;

    public ReservationsController(IReservationService service)
    {
        _service = service;
    }

    [HttpPost]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<ReservationDetailsDto>> Create(CreateReservationDto dto)
    {
        var created = await _service.CreateAsync(User.GetUserId(), dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpGet("mine")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<PagedResultDto<ReservationDto>>> GetMine([FromQuery] ReservationQueryDto query)
        => Ok(await _service.GetMineAsync(User.GetUserId(), query));

    [HttpGet]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<PagedResultDto<ReservationDto>>> GetAll([FromQuery] ReservationQueryDto query)
        => Ok(await _service.GetAllAsync(query));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ReservationDetailsDto>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id, User.GetUserId(), User.IsAdministrator()));

    [HttpPost("{id:int}/confirm")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<ReservationDetailsDto>> Confirm(int id)
        => Ok(await _service.ConfirmAsync(id, User.GetUserId()));

    // Član otkazuje svoju rezervaciju; bibliotekar otkazuje ili odbija uz obavezan razlog.
    [HttpPost("{id:int}/cancel")]
    public async Task<ActionResult<ReservationDetailsDto>> Cancel(int id, CancelReservationDto dto)
        => Ok(await _service.CancelAsync(id, User.GetUserId(), User.IsAdministrator(), dto.Reason));
}
