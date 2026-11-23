using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/fines")]
[Authorize]
public class FinesController : ControllerBase
{
    private readonly IFineService _service;

    public FinesController(IFineService service)
    {
        _service = service;
    }

    [HttpGet]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<PagedResultDto<FineDto>>> GetAll([FromQuery] FineQueryDto query)
        => Ok(await _service.GetAllAsync(query));

    [HttpGet("mine")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<PagedResultDto<FineDto>>> GetMine([FromQuery] FineQueryDto query)
        => Ok(await _service.GetMineAsync(User.GetUserId(), query));

    [HttpPost("{id:int}/pay-at-counter")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<FineDto>> PayAtCounter(int id)
        => Ok(await _service.PayAtCounterAsync(User.GetUserId(), id));
}
