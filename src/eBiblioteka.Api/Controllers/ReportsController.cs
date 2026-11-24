using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Route("api/reports")]
[Authorize(Roles = Roles.Administrator)]
public class ReportsController : ControllerBase
{
    private const string PdfContentType = "application/pdf";

    private readonly IReportService _service;

    public ReportsController(IReportService service)
    {
        _service = service;
    }

    [HttpGet("loans")]
    public async Task<ActionResult<LoanReportDto>> GetLoanReport([FromQuery] LoanReportQueryDto query)
        => Ok(await _service.GetLoanReportAsync(query));

    [HttpGet("loans/pdf")]
    public async Task<IActionResult> GetLoanReportPdf([FromQuery] LoanReportQueryDto query)
    {
        var pdf = await _service.GetLoanReportPdfAsync(query, User.GetUserId());
        return File(pdf, PdfContentType, "izvjestaj-posudbe.pdf");
    }

    [HttpGet("fines")]
    public async Task<ActionResult<FineReportDto>> GetFineReport([FromQuery] FineReportQueryDto query)
        => Ok(await _service.GetFineReportAsync(query));

    [HttpGet("fines/pdf")]
    public async Task<IActionResult> GetFineReportPdf([FromQuery] FineReportQueryDto query)
    {
        var pdf = await _service.GetFineReportPdfAsync(query, User.GetUserId());
        return File(pdf, PdfContentType, "izvjestaj-zakasnine.pdf");
    }
}
