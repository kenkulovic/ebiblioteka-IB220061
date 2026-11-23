using eBiblioteka.Api.Data.Enums;

namespace eBiblioteka.Api.Dtos;

public class LoanQueryDto : PagedQueryDto
{
    public LoanFilter? Filter { get; set; }
}
