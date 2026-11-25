using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IPaymentService
{
    Task<PaymentInitDto> StartPayPalPaymentAsync(int userId, int fineId);
    Task<PaymentDto> CaptureAsync(int userId, int paymentId);
    Task<PaymentDto> CancelAsync(int userId, int paymentId);
    Task<PaymentDto> RefundAsync(int adminId, int paymentId, string reason);
    Task<PaymentDto> GetByIdAsync(int paymentId, int actorId, bool isAdmin);
    Task<PagedResultDto<PaymentDto>> GetForFineAsync(int fineId, PagedQueryDto query);
}
