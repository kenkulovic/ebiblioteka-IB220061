namespace eBiblioteka.Api.Dtos;

public class NewsDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Text { get; set; } = string.Empty;
    public DateTime PublishedAt { get; set; }
}
