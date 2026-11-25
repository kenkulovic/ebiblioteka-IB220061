using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Helpers;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/news")]
[Authorize]
public class NewsController : ControllerBase
{
    private readonly INewsService _service;

    public NewsController(INewsService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<NewsDto>>> Get([FromQuery] PagedQueryDto query)
        => Ok(await _service.GetAsync(query));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<NewsDto>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id));

    [HttpGet("{id:int}/image")]
    public async Task<IActionResult> GetImage(int id)
    {
        var image = await _service.GetImageAsync(id);
        return File(image.Data, image.ContentType);
    }

    [HttpPost]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<NewsDto>> Create([FromForm] NewsFormDto form)
    {
        if (form.Image == null)
        {
            throw new BadRequestException("Slika obavijesti je obavezna.");
        }

        EnsureImageContentType(form.Image);
        await using var stream = form.Image.OpenReadStream();
        var created = await _service.CreateAsync(User.GetUserId(), form.Title, form.Text, stream, form.Image.Length);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<NewsDto>> Update(int id, [FromForm] NewsFormDto form)
    {
        if (form.Image == null)
        {
            return Ok(await _service.UpdateAsync(id, form.Title, form.Text, null, 0));
        }

        EnsureImageContentType(form.Image);
        await using var stream = form.Image.OpenReadStream();
        return Ok(await _service.UpdateAsync(id, form.Title, form.Text, stream, form.Image.Length));
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<IActionResult> Delete(int id)
    {
        await _service.DeleteAsync(id);
        return NoContent();
    }

    private static void EnsureImageContentType(IFormFile image)
    {
        if (!ImageFormat.IsAllowedContentType(image.ContentType))
        {
            throw new BadRequestException("Dozvoljeni formati slike su PNG i JPEG.");
        }
    }
}
