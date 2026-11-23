using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface IReportService
{
    Task<LoanReportDto> GetLoanReportAsync(ReportQueryDto query);
    Task<FineReportDto> GetFineReportAsync(ReportQueryDto query);
    Task<byte[]> GetLoanReportPdfAsync(ReportQueryDto query, int adminId);
    Task<byte[]> GetFineReportPdfAsync(ReportQueryDto query, int adminId);
}
