using eBiblioteka.Shared.Messaging;

namespace eBiblioteka.Api.Services.Email;

public interface IEmailQueue
{
    // Stavlja e-mail u RabbitMQ red; stvarno slanje obavlja Worker.
    // Vraća false ako red nije dostupan: nedostupan red ne smije srušiti glavnu radnju.
    Task<bool> EnqueueAsync(EmailMessage message);
}
