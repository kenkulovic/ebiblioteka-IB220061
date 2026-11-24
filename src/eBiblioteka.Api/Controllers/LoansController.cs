using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/loans")]
[Authorize]
public class LoansController : ControllerBase
{
    private readonly ILoanService _service;

    public LoansController(ILoanService service)
    {
        _service = service;
    }

    [HttpPost]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<LoanDto>> Issue(IssueLoanDto dto)
        => Ok(await _service.IssueAsync(User.GetUserId(), dto));

    [HttpGet]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<PagedResultDto<LoanDto>>> GetAll([FromQuery] LoanQueryDto query)
        => Ok(await _service.GetAllAsync(query));

    [HttpGet("issue-check")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<IssueCheckDto>> CheckIssue([FromQuery] int userId, [FromQuery] int bookId)
        => Ok(await _service.CheckIssueAsync(userId, bookId));

    [HttpGet("{id:int}/return-preview")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<ReturnPreviewDto>> PreviewReturn(int id)
        => Ok(await _service.PreviewReturnAsync(id));

    [HttpGet("mine")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<PagedResultDto<LoanDto>>> GetMine([FromQuery] LoanQueryDto query)
        => Ok(await _service.GetMineAsync(User.GetUserId(), query));

    [HttpPost("{id:int}/return")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<LoanDto>> Return(int id)
        => Ok(await _service.ReturnAsync(User.GetUserId(), id));

    [HttpPost("{id:int}/extend")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<LoanDto>> Extend(int id)
        => Ok(await _service.ExtendAsync(User.GetUserId(), id));
}
