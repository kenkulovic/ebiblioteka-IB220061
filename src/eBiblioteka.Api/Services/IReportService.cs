using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IReportService
{
    Task<LoanReportDto> GetLoanReportAsync(LoanReportQueryDto query);
    Task<FineReportDto> GetFineReportAsync(FineReportQueryDto query);
    Task<byte[]> GetLoanReportPdfAsync(LoanReportQueryDto query, int adminId);
    Task<byte[]> GetFineReportPdfAsync(FineReportQueryDto query, int adminId);
}
