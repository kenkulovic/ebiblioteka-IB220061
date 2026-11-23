namespace eBiblioteka.Api.Dtos;

public class ImageDto
{
    public byte[] Data { get; set; } = Array.Empty<byte>();
    public string ContentType { get; set; } = string.Empty;
}
