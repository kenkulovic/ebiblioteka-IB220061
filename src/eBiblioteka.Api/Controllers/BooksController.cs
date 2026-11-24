using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Helpers;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/books")]
[Authorize]
public class BooksController : ControllerBase
{
    private readonly IBookService _service;

    public BooksController(IBookService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<BookListItemDto>>> Get([FromQuery] BookQueryDto query)
        => Ok(await _service.GetAsync(query));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<BookDetailsDto>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id));

    [HttpPost]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<BookDetailsDto>> Create(BookUpsertDto dto)
    {
        var created = await _service.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<BookDetailsDto>> Update(int id, BookUpsertDto dto)
        => Ok(await _service.UpdateAsync(id, dto));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<IActionResult> Delete(int id)
    {
        await _service.DeleteAsync(id);
        return NoContent();
    }

    [HttpGet("{id:int}/cover")]
    public async Task<IActionResult> GetCover(int id)
    {
        var cover = await _service.GetCoverAsync(id);
        return File(cover.Data, cover.ContentType);
    }

    [HttpPut("{id:int}/cover")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<IActionResult> SetCover(int id, IFormFile file)
    {
        if (!ImageFormat.IsAllowedContentType(file.ContentType))
        {
            throw new BadRequestException("Dozvoljeni formati slike su PNG i JPEG.");
        }

        await using var stream = file.OpenReadStream();
        await _service.SetCoverAsync(id, stream, file.Length);
        return NoContent();
    }

    [HttpDelete("{id:int}/cover")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<IActionResult> RemoveCover(int id)
    {
        await _service.RemoveCoverAsync(id);
        return NoContent();
    }
}
