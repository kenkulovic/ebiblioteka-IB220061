using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;
using eBiblioteka.Api.Extensions;
using eBiblioteka.Api.Helpers;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Services;

public class NewsService : INewsService
{
    private const long MaxImageBytes = 2 * 1024 * 1024;

    private readonly AppDbContext _db;
    private readonly ILogger<NewsService> _logger;

    public NewsService(AppDbContext db, ILogger<NewsService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<PagedResultDto<NewsDto>> GetAsync(PagedQueryDto query)
    {
        var news = _db.News.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            news = news.Where(n => n.Title.Contains(search) || n.Text.Contains(search));
        }

        // Slika se ne učitava u listu: klijent je dohvaća posebno (GET /api/news/{id}/image).
        return await news
            .OrderByDescending(n => n.PublishedAt)
            .ThenByDescending(n => n.Id)
            .Select(n => new NewsDto { Id = n.Id, Title = n.Title, Text = n.Text, PublishedAt = n.PublishedAt })
            .ToPagedAsync(query);
    }

    public async Task<NewsDto> GetByIdAsync(int id) =>
        await _db.News.AsNoTracking()
            .Where(n => n.Id == id)
            .Select(n => new NewsDto { Id = n.Id, Title = n.Title, Text = n.Text, PublishedAt = n.PublishedAt })
            .FirstOrDefaultAsync()
        ?? throw new NotFoundException("Obavijest nije pronađena.");

    public async Task<NewsDto> CreateAsync(int adminId, string title, string text, Stream image, long imageLength)
    {
        var data = await ReadImageAsync(image, imageLength);

        var news = new News
        {
            Title = title.Trim(),
            Text = text.Trim(),
            Image = data,
            PublishedAt = DateTime.UtcNow,
            CreatedByUserId = adminId
        };
        _db.News.Add(news);
        await _db.SaveChangesAsync();

        _logger.LogInformation("Objavljena obavijest {NewsId}: {Title}", news.Id, news.Title);

        return await GetByIdAsync(news.Id);
    }

    public async Task<NewsDto> UpdateAsync(int id, string title, string text, Stream? image, long imageLength)
    {
        var news = await _db.News.FirstOrDefaultAsync(n => n.Id == id)
            ?? throw new NotFoundException("Obavijest nije pronađena.");

        news.Title = title.Trim();
        news.Text = text.Trim();

        if (image != null)
        {
            news.Image = await ReadImageAsync(image, imageLength);
        }

        await _db.SaveChangesAsync();

        return await GetByIdAsync(id);
    }

    public async Task DeleteAsync(int id)
    {
        var news = await _db.News.FirstOrDefaultAsync(n => n.Id == id)
            ?? throw new NotFoundException("Obavijest nije pronađena.");

        _db.News.Remove(news);
        await _db.SaveChangesAsync();
    }

    public async Task<ImageDto> GetImageAsync(int id)
    {
        var image = await _db.News.AsNoTracking()
            .Where(n => n.Id == id)
            .Select(n => n.Image)
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Obavijest nije pronađena.");

        return new ImageDto
        {
            Data = image,
            ContentType = ImageFormat.Detect(image) ?? ImageFormat.Jpeg
        };
    }

    private static async Task<byte[]> ReadImageAsync(Stream content, long length)
    {
        if (length <= 0 || length > MaxImageBytes)
        {
            throw new BadRequestException("Slika mora biti veličine do 2 MB.");
        }

        using var buffer = new MemoryStream();
        await content.CopyToAsync(buffer);
        var data = buffer.ToArray();

        if (ImageFormat.Detect(data) == null)
        {
            throw new BadRequestException("Dozvoljeni formati slike su PNG i JPEG.");
        }

        return data;
    }
}
