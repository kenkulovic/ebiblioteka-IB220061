using eBiblioteka.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Data;

public static partial class DbSeeder
{
    private sealed record SeedBook(
        string CoverSlug,
        string Title,
        int Year,
        int Pages,
        string Description,
        int Copies,
        string Category,
        string Publisher,
        params string[] AuthorKeys);

    private static async Task SeedCatalogAsync(AppDbContext db)
    {
        if (await db.Authors.AnyAsync())
        {
            return;
        }

        var countries = await db.Countries.ToDictionaryAsync(c => c.Name, c => c.Id);
        var categories = await db.Categories.ToDictionaryAsync(c => c.Name, c => c.Id);
        var publishers = await db.Publishers.ToDictionaryAsync(p => p.Name, p => p.Id);

        var authors = new Dictionary<string, Author>
        {
            ["andric"] = NewAuthor("Ivo", "Andrić", countries["Bosna i Hercegovina"],
                "Bosanski i jugoslavenski pisac, dobitnik Nobelove nagrade za književnost 1961. godine."),
            ["selimovic"] = NewAuthor("Meša", "Selimović", countries["Bosna i Hercegovina"],
                "Pisac iz Tuzle, autor romana o savjesti i pojedincu u vremenu u kojem živi."),
            ["dizdar"] = NewAuthor("Mak", "Dizdar", countries["Bosna i Hercegovina"],
                "Pjesnik koji je u poeziju unio motive srednjovjekovnih bosanskih stećaka."),
            ["copic"] = NewAuthor("Branko", "Ćopić", countries["Bosna i Hercegovina"],
                "Pisac za djecu i odrasle, poznat po humoru i toplim pričama o djetinjstvu."),
            ["krleza"] = NewAuthor("Miroslav", "Krleža", countries["Hrvatska"],
                "Hrvatski pisac i enciklopedist, jedan od najuticajnijih autora regije u 20. stoljeću."),
            ["kis"] = NewAuthor("Danilo", "Kiš", countries["Srbija"],
                "Pisac koji se u prozi bavio sudbinom pojedinca u totalitarnim sistemima."),
            ["marquez"] = NewAuthor("Gabriel", "García Márquez", countries["Kolumbija"],
                "Kolumbijski pisac, predstavnik magijskog realizma i nobelovac iz 1982. godine."),
            ["tolstoj"] = NewAuthor("Lav", "Tolstoj", countries["Rusija"],
                "Ruski pisac, autor jednih od najpoznatijih romana svjetske književnosti."),
            ["orwell"] = NewAuthor("George", "Orwell", countries["Velika Britanija"],
                "Britanski pisac i novinar, poznat po djelima o politici i nadzoru."),
            ["hawking"] = NewAuthor("Stephen", "Hawking", countries["Velika Britanija"],
                "Britanski fizičar koji je široj publici približio kosmologiju i crne rupe."),
            ["malcolm"] = NewAuthor("Noel", "Malcolm", countries["Velika Britanija"],
                "Britanski historičar koji se bavio historijom Balkana."),
            ["frank"] = NewAuthor("Anne", "Frank", countries["Njemačka"],
                "Autorica dnevnika nastalog tokom skrivanja u Amsterdamu u Drugom svjetskom ratu.")
        };

        var seedBooks = new[]
        {
            new SeedBook("na-drini-cuprija", "Na Drini ćuprija", 1945, 340,
                "Hronika višegradskog mosta i generacija ljudi koje su živjele pored njega.",
                3, "Roman", "Svjetlost", "andric"),
            new SeedBook("prokleta-avlija", "Prokleta avlija", 1954, 110,
                "Kratki roman smješten u istanbulski zatvor, o pričanju priča i ljudskoj sudbini.",
                2, "Roman", "Buybook", "andric"),
            new SeedBook("travnicka-hronika", "Travnička hronika", 1945, 420,
                "Roman o životu konzula u Travniku u vrijeme Napoleonovih ratova.",
                2, "Roman", "Svjetlost", "andric"),
            new SeedBook("dervis-i-smrt", "Derviš i smrt", 1966, 360,
                "Roman o dervišu Ahmedu Nurudinu, savjesti i moći u osmanskoj Bosni.",
                3, "Roman", "Buybook", "selimovic"),
            new SeedBook("tvrdjava", "Tvrđava", 1970, 440,
                "Roman o Ahmetu Šabu, ratu i traženju smisla i pripadnosti.",
                2, "Roman", "Svjetlost", "selimovic"),
            new SeedBook("kameni-spavac", "Kameni spavač", 1966, 150,
                "Zbirka poezije nadahnuta natpisima na srednjovjekovnim stećcima.",
                2, "Poezija", "Zora", "dizdar"),
            new SeedBook("orlovi-rano-lete", "Orlovi rano lete", 1957, 120,
                "Priča o grupi dječaka u Drugom svjetskom ratu, za mlađe čitatelje.",
                4, "Dječija književnost", "Zora", "copic"),
            new SeedBook("jezeva-kucica", "Ježeva kućica", 1949, 40,
                "Slikovnica o ježu koji se brine za svoju kućicu i prijatelje.",
                3, "Dječija književnost", "Zora", "copic"),
            new SeedBook("povratak-filipa-latinovicza", "Povratak Filipa Latinovicza", 1932, 300,
                "Roman o slikaru koji se nakon dugog izbivanja vraća u rodni kraj.",
                1, "Roman", "Laguna", "krleza"),
            new SeedBook("grobnica-za-borisa-davidovica", "Grobnica za Borisa Davidoviča", 1976, 160,
                "Zbirka pripovijedaka o sudbinama ljudi u revolucionarnim previranjima.",
                1, "Roman", "Laguna", "kis"),
            new SeedBook("sto-godina-samoce", "Sto godina samoće", 1967, 420,
                "Saga o porodici Buendía kroz sedam generacija u izmišljenom gradu Macondu.",
                3, "Roman", "Laguna", "marquez"),
            new SeedBook("ana-karenjina", "Ana Karenjina", 1877, 800,
                "Roman o ljubavi, braku i društvenim konvencijama u carskoj Rusiji.",
                2, "Roman", "Laguna", "tolstoj"),
            new SeedBook("1984", "1984", 1949, 330,
                "Distopijski roman o društvu pod stalnim nadzorom i kontrolom istine.",
                4, "Roman", "Buybook", "orwell"),
            new SeedBook("zivotinjska-farma", "Životinjska farma", 1945, 110,
                "Alegorijska priča o životinjama koje preuzimaju farmu i vlast.",
                3, "Roman", "Buybook", "orwell"),
            new SeedBook("kratka-historija-vremena", "Kratka historija vremena", 1988, 250,
                "Popularno-naučna knjiga o postanku svemira, crnim rupama i prirodi vremena.",
                2, "Nauka", "Buybook", "hawking"),
            new SeedBook("bosna-kratka-historija", "Bosna: kratka historija", 1994, 340,
                "Pregled historije Bosne od srednjeg vijeka do kraja 20. stoljeća.",
                2, "Historija", "Svjetlost", "malcolm"),
            new SeedBook("dnevnik-ane-frank", "Dnevnik Ane Frank", 1947, 280,
                "Dnevnik djevojčice koja se s porodicom skrivala od progona u Drugom svjetskom ratu.",
                3, "Biografija", "Zora", "frank")
        };

        db.Authors.AddRange(authors.Values);

        foreach (var seed in seedBooks)
        {
            var book = new Book
            {
                Title = seed.Title,
                PublishedYear = seed.Year,
                PageCount = seed.Pages,
                Description = seed.Description,
                TotalCopies = seed.Copies,
                CategoryId = categories[seed.Category],
                PublisherId = publishers[seed.Publisher],
                CoverImage = await ReadCoverAsync(seed.CoverSlug)
            };

            foreach (var key in seed.AuthorKeys)
            {
                book.BookAuthors.Add(new BookAuthor { Author = authors[key] });
            }

            db.Books.Add(book);
        }

        // Autori, knjige i veze se upisuju zajedno, u jednoj transakciji.
        await db.SaveChangesAsync();
    }

    private static Author NewAuthor(string firstName, string lastName, int countryId, string biography) =>
        new()
        {
            FirstName = firstName,
            LastName = lastName,
            CountryId = countryId,
            Biography = biography
        };

    private static async Task<byte[]?> ReadCoverAsync(string slug)
    {
        var path = Path.Combine(AppContext.BaseDirectory, "SeedData", "Covers", slug + ".png");
        return File.Exists(path) ? await File.ReadAllBytesAsync(path) : null;
    }
}
