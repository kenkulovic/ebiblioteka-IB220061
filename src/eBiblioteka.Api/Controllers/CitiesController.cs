using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/cities")]
[Authorize]
public class CitiesController : ControllerBase
{
    private readonly ICityService _service;

    public CitiesController(ICityService service)
    {
        _service = service;
    }

    // Lista gradova je javna: potrebna je na ekranu registracije, prije prijave.
    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<PagedResultDto<CityDto>>> Get([FromQuery] PagedQueryDto query, [FromQuery] int? countryId)
        => Ok(await _service.GetAsync(query, countryId));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<CityDto>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id));

    [HttpPost]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<CityDto>> Create(CityUpsertDto dto)
    {
        var created = await _service.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<CityDto>> Update(int id, CityUpsertDto dto)
        => Ok(await _service.UpdateAsync(id, dto));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<IActionResult> Delete(int id)
    {
        await _service.DeleteAsync(id);
        return NoContent();
    }
}
