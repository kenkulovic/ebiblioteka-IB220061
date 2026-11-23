using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface ILoanService
{
    Task<LoanDto> IssueAsync(int adminId, IssueLoanDto dto);
    Task<LoanDto> ReturnAsync(int adminId, int loanId);
    Task<LoanDto> ExtendAsync(int userId, int loanId);
    Task<PagedResultDto<LoanDto>> GetMineAsync(int userId, LoanQueryDto query);
    Task<PagedResultDto<LoanDto>> GetAllAsync(LoanQueryDto query);
}
