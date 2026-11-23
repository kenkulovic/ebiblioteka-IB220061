using eBiblioteka.Shared.Messaging;

namespace eBiblioteka.Worker;

public interface IEmailSender
{
    Task SendAsync(EmailMessage message, CancellationToken cancellationToken);
}
