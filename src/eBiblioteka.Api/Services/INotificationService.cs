using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface INotificationService
{
    // Dodaje obavijest u kontekst, ali ne snima: snima pozivalac, u istoj transakciji kao i glavna promjena.
    void Add(int userId, string title, string text);

    Task<PagedResultDto<NotificationDto>> GetMineAsync(int userId, NotificationQueryDto query);
    Task<int> GetUnreadCountAsync(int userId);
    Task MarkAsReadAsync(int userId, int notificationId);
    Task MarkAllAsReadAsync(int userId);
}
