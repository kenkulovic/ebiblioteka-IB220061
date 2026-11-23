using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/authors")]
[Authorize]
public class AuthorsController : ControllerBase
{
    private readonly IAuthorService _service;

    public AuthorsController(IAuthorService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<AuthorDto>>> Get([FromQuery] PagedQueryDto query)
        => Ok(await _service.GetAsync(query));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<AuthorDto>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id));

    [HttpPost]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<AuthorDto>> Create(AuthorUpsertDto dto)
    {
        var created = await _service.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<AuthorDto>> Update(int id, AuthorUpsertDto dto)
        => Ok(await _service.UpdateAsync(id, dto));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<IActionResult> Delete(int id)
    {
        await _service.DeleteAsync(id);
        return NoContent();
    }
}
