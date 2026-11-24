namespace eBiblioteka.Api.Helpers;

public static class ImageFormat
{
    public const string Png = "image/png";
    public const string Jpeg = "image/jpeg";

    // MIME tip koji klijent šalje mora biti PNG ili JPEG; sadržaj se zatim provjerava po magic bytes (Detect).
    public static bool IsAllowedContentType(string? contentType) =>
        string.Equals(contentType, Png, StringComparison.OrdinalIgnoreCase) ||
        string.Equals(contentType, Jpeg, StringComparison.OrdinalIgnoreCase);

    // Tip slike se određuje po stvarnom sadržaju (prvi bajtovi), a ne po nazivu fajla koji šalje klijent.
    public static string? Detect(byte[] data)
    {
        if (data.Length >= 8 &&
            data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47)
        {
            return Png;
        }

        if (data.Length >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF)
        {
            return Jpeg;
        }

        return null;
    }
}
