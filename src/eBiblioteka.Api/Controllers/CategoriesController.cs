using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/categories")]
[Authorize]
public class CategoriesController : ControllerBase
{
    private readonly ICategoryService _service;

    public CategoriesController(ICategoryService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<LookupDto>>> Get([FromQuery] PagedQueryDto query)
        => Ok(await _service.GetAsync(query));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<LookupDto>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id));

    [HttpPost]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<LookupDto>> Create(LookupUpsertDto dto)
    {
        var created = await _service.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<LookupDto>> Update(int id, LookupUpsertDto dto)
        => Ok(await _service.UpdateAsync(id, dto));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<IActionResult> Delete(int id)
    {
        await _service.DeleteAsync(id);
        return NoContent();
    }
}
