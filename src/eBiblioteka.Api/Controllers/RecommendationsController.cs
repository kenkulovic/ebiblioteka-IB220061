using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services;
using eBiblioteka.Api.Services.Recommender;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Authorize]
public class RecommendationsController : ControllerBase
{
    private readonly IRecommendationService _service;

    public RecommendationsController(IRecommendationService service)
    {
        _service = service;
    }

    [HttpGet("api/recommendations")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<List<RecommendationDto>>> GetForMe(
        [FromQuery] int count = RecommenderSettings.DefaultCount)
        => Ok(await _service.GetForUserAsync(User.GetUserId(), count));

    [HttpGet("api/books/{bookId:int}/similar")]
    public async Task<ActionResult<List<SimilarBookDto>>> GetSimilar(
        int bookId, [FromQuery] int count = RecommenderSettings.DefaultCount)
        => Ok(await _service.GetSimilarBooksAsync(bookId, count));

    [HttpPost("api/recommendations/recalculate")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<int>> Recalculate()
        => Ok(await _service.RecalculateAsync());
}
