namespace eBiblioteka.Api.Dtos;

public class BookCoverDto
{
    public byte[] Data { get; set; } = Array.Empty<byte>();
    public string ContentType { get; set; } = string.Empty;
}
