namespace eBiblioteka.Api.Data.Entities;

public class News
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Text { get; set; } = string.Empty;
    public byte[] Image { get; set; } = Array.Empty<byte>();
    public DateTime PublishedAt { get; set; } = DateTime.UtcNow;

    // Bibliotekar koji je objavio obavijest.
    public int CreatedByUserId { get; set; }
    public ApplicationUser CreatedByUser { get; set; } = null!;
}