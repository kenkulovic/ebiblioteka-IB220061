namespace eBiblioteka.Shared.Messaging;

// Poruka koju API stavlja u RabbitMQ red, a Worker je pretvara u stvarni e-mail.
public record EmailMessage(string To, string Subject, string Body);
