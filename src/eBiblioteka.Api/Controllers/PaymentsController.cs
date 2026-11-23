using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eBiblioteka.Api.Controllers;

[ApiController]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService _service;

    public PaymentsController(IPaymentService service)
    {
        _service = service;
    }

    // Član pokreće online plaćanje svoje zakasnine; iznos određuje server.
    [HttpPost("api/fines/{fineId:int}/payments")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<PaymentInitDto>> Start(int fineId)
        => Ok(await _service.StartPayPalPaymentAsync(User.GetUserId(), fineId));

    [HttpGet("api/fines/{fineId:int}/payments")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<List<PaymentDto>>> GetForFine(int fineId)
        => Ok(await _service.GetForFineAsync(fineId));

    [HttpGet("api/payments/{id:int}")]
    public async Task<ActionResult<PaymentDto>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id, User.GetUserId(), User.IsAdministrator()));

    // Uplata je uspješna tek kad je server potvrdi preko PayPal API-ja. Poziv je idempotentan.
    [HttpPost("api/payments/{id:int}/capture")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<PaymentDto>> Capture(int id)
        => Ok(await _service.CaptureAsync(User.GetUserId(), id));

    [HttpPost("api/payments/{id:int}/cancel")]
    [Authorize(Roles = Roles.Member)]
    public async Task<ActionResult<PaymentDto>> Cancel(int id)
        => Ok(await _service.CancelAsync(User.GetUserId(), id));

    [HttpPost("api/payments/{id:int}/refund")]
    [Authorize(Roles = Roles.Administrator)]
    public async Task<ActionResult<PaymentDto>> Refund(int id, RefundPaymentDto dto)
        => Ok(await _service.RefundAsync(User.GetUserId(), id, dto.Reason));
}
