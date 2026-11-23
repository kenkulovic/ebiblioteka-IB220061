namespace eBiblioteka.Api.Dtos;

public class NotificationQueryDto : PagedQueryDto
{
    public bool OnlyUnread { get; set; }
}
