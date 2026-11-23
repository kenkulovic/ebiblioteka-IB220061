using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Authorize]
public class ReviewsController : ControllerBase
{
    private readonly IReviewService _service;

    public ReviewsController(IReviewService service)
    {
        _service = service;
    }

    [HttpPost("api/reviews")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<ReviewDto>> Create(ReviewCreateDto dto)
        => Ok(await _service.CreateAsync(User.GetUserId(), dto));

    [HttpPut("api/reviews/{id:int}")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<ReviewDto>> Update(int id, ReviewUpdateDto dto)
        => Ok(await _service.UpdateAsync(User.GetUserId(), id, dto));

    [HttpGet("api/reviews/mine")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<PagedResultDto<ReviewDto>>> GetMine([FromQuery] PagedQueryDto query)
        => Ok(await _service.GetMineAsync(User.GetUserId(), query));

    [HttpGet("api/books/{bookId:int}/reviews")]
    public async Task<ActionResult<PagedResultDto<ReviewDto>>> GetForBook(int bookId, [FromQuery] PagedQueryDto query)
        => Ok(await _service.GetForBookAsync(bookId, query));
}
