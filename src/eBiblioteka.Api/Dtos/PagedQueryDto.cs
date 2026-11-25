namespace eBiblioteka.Api.Dtos;

public class PagedQueryDto
{
    public const int MaxPageSize = 50;
    private const int DefaultPageSize = 10;

    private int _page = 1;
    private int _pageSize = DefaultPageSize;

    public int Page
    {
        get => _page;
        set => _page = value < 1 ? 1 : value;
    }

    public int PageSize
    {
        get => _pageSize;
        set => _pageSize = value < 1 ? DefaultPageSize : Math.Min(value, MaxPageSize);
    }

    public string? Search { get; set; }

    // Za administratorske liste: posljednje dodani zapis na vrhu (inače abecedno).
    public bool NewestFirst { get; set; }
}
