using eBiblioteka.Api.Dtos;

namespace eBiblioteka.Api.Services;

public interface INotificationService
{
    // Dodaje obavijest u kontekst, ali ne snima: snima pozivalac, u istoj transakciji kao i glavna promjena.
    void Add(int userId, string title, string text);

    // Isto kao Add, ali se obavijest dodatno šalje e-mailom. E-mail se šalje tek pozivom
    // SendPendingEmailsAsync, nakon što je promjena u bazi potvrđena.
    void AddWithEmail(int userId, string title, string text);

    // Stavlja zapamćene e-mailove u RabbitMQ red (Worker ih šalje). Poziva se nakon commita.
    Task SendPendingEmailsAsync();

    Task<PagedResultDto<NotificationDto>> GetMineAsync(int userId, NotificationQueryDto query);
    Task<int> GetUnreadCountAsync(int userId);
    Task MarkAsReadAsync(int userId, int notificationId);
    Task MarkAllAsReadAsync(int userId);
}
