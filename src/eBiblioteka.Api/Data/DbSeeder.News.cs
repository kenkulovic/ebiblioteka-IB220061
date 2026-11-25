using eBiblioteka.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Data;

public static partial class DbSeeder
{
    private static async Task SeedNewsAsync(AppDbContext db)
    {
        if (await db.News.AnyAsync())
        {
            return;
        }

        var adminId = await db.Users.Where(u => u.UserName == "desktop").Select(u => u.Id).FirstAsync();
        var now = DateTime.UtcNow;
        var items = new[]
        {
            (Slug: "radno-vrijeme", Title: "Novo radno vrijeme",
                Text: "Od ovog mjeseca biblioteka radi radnim danima od 8 do 19 sati, a subotom od 9 do 14 sati. Nedjeljom ne radimo.",
                Age: TimeSpan.FromDays(10)),
            (Slug: "nove-knjige", Title: "Nove knjige u katalogu",
                Text: "Katalog je dopunjen novim naslovima iz romana, poezije i popularne nauke. Pretražite katalog i rezervišite knjigu iz aplikacije.",
                Age: TimeSpan.FromDays(4)),
            (Slug: "preporuke", Title: "Preporuke za vas",
                Text: "Ocijenite pročitane knjige i na početnom ekranu ćete dobiti prijedloge knjiga koje bi vam se mogle svidjeti, uz objašnjenje zašto.",
                Age: TimeSpan.FromDays(1))
        };

        foreach (var item in items)
        {
            var path = Path.Combine(AppContext.BaseDirectory, "SeedData", "News", item.Slug + ".png");
            if (!File.Exists(path))
            {
                continue;
            }

            db.News.Add(new News
            {
                Title = item.Title,
                Text = item.Text,
                Image = await File.ReadAllBytesAsync(path),
                PublishedAt = now - item.Age,
                CreatedByUserId = adminId
            });
        }

        await db.SaveChangesAsync();
    }
}
