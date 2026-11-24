namespace eBiblioteka.Api.Dtos;

public class MemberQueryDto : PagedQueryDto
{
    public bool? IsBlocked { get; set; }
    public int? CityId { get; set; }
}
