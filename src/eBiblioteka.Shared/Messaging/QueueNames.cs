namespace eBiblioteka.Shared.Messaging;

public static class QueueNames
{
    public const string Email = "ebiblioteka.email";

    // E-mailovi koji nisu poslani ni nakon svih pokušaja ostaju ovdje na ručni pregled.
    public const string EmailDead = "ebiblioteka.email.dead";
}
