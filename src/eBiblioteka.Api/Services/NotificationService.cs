using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Services.Email;
using eBiblioteka.Shared.Messaging;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class NotificationService : INotificationService
{
    private readonly AppDbContext _db;
    private readonly IEmailQueue _emailQueue;
    private readonly List<(int UserId, string Title, string Text)> _pendingEmails = new();

    public NotificationService(AppDbContext db, IEmailQueue emailQueue)
    {
        _db = db;
        _emailQueue = emailQueue;
    }

    public void Add(int userId, string title, string text)
    {
        _db.Notifications.Add(new Notification
        {
            UserId = userId,
            Title = title,
            Text = text,
            CreatedAt = DateTime.UtcNow
        });
    }

    public void AddWithEmail(int userId, string title, string text)
    {
        Add(userId, title, text);
        _pendingEmails.Add((userId, title, text));
    }

    public async Task SendPendingEmailsAsync()
    {
        if (_pendingEmails.Count == 0)
        {
            return;
        }

        var pending = _pendingEmails.ToList();
        _pendingEmails.Clear();

        var userIds = pending.Select(p => p.UserId).Distinct().ToList();
        var recipients = await _db.Users.AsNoTracking()
            .Where(u => userIds.Contains(u.Id) && u.Email != null)
            .Select(u => new { u.Id, u.Email, u.FirstName })
            .ToDictionaryAsync(u => u.Id);

        foreach (var (userId, title, text) in pending)
        {
            if (!recipients.TryGetValue(userId, out var recipient))
            {
                continue;
            }

            var body = $"Poštovani/a {recipient.FirstName},\n\n{text}\n\neBiblioteka";
            await _emailQueue.EnqueueAsync(new EmailMessage(recipient.Email!, $"eBiblioteka: {title}", body));
        }
    }

    public async Task<PagedResultDto<NotificationDto>> GetMineAsync(int userId, NotificationQueryDto query)
    {
        var notifications = _db.Notifications.AsNoTracking().Where(n => n.UserId == userId);

        if (query.OnlyUnread)
        {
            notifications = notifications.Where(n => !n.IsRead);
        }

        return await notifications
            .OrderByDescending(n => n.CreatedAt)
            .ThenByDescending(n => n.Id)
            .Select(n => new NotificationDto
            {
                Id = n.Id,
                Title = n.Title,
                Text = n.Text,
                IsRead = n.IsRead,
                CreatedAt = n.CreatedAt
            })
            .ToPagedAsync(query);
    }

    public async Task<int> GetUnreadCountAsync(int userId) =>
        await _db.Notifications.CountAsync(n => n.UserId == userId && !n.IsRead);

    public async Task MarkAsReadAsync(int userId, int notificationId)
    {
        // Tuđa obavijest se prikazuje kao nepostojeća.
        var notification = await _db.Notifications
            .FirstOrDefaultAsync(n => n.Id == notificationId && n.UserId == userId)
            ?? throw new NotFoundException("Obavijest nije pronađena.");

        if (!notification.IsRead)
        {
            notification.IsRead = true;
            await _db.SaveChangesAsync();
        }
    }

    public async Task MarkAllAsReadAsync(int userId)
    {
        await _db.Notifications
            .Where(n => n.UserId == userId && !n.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));
    }
}
