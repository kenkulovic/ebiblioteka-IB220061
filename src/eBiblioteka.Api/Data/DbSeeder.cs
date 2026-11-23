using eBiblioteka.Api.Constants;
using eBiblioteka.Api.Data.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Data;

public static partial class DbSeeder
{
    public static async Task SeedAsync(IServiceProvider services)
    {
        var db = services.GetRequiredService<AppDbContext>();
        await db.Database.MigrateAsync();

        await SeedRolesAsync(services);
        await SeedLookupsAsync(db);
        await SeedUsersAsync(services, db);
        await SeedCatalogAsync(db);
        await SeedActivityAsync(db);
        await SeedNewsAsync(db);
    }

    private static async Task SeedUsersAsync(IServiceProvider services, AppDbContext db)
    {
        var userManager = services.GetRequiredService<UserManager<ApplicationUser>>();
        var cities = await db.Cities.ToDictionaryAsync(c => c.Name, c => c.Id);

        await CreateUserAsync(userManager, "desktop", "Bibliotekar", "Glavni", "CL-000000", cities["Mostar"], Roles.Administrator);
        await CreateUserAsync(userManager, "mobile", "Lejla", "Hodžić", "CL-000001", cities["Mostar"], Roles.Member);
        await CreateUserAsync(userManager, "maja", "Maja", "Perić", "CL-000002", cities["Sarajevo"], Roles.Member);
        await CreateUserAsync(userManager, "adnan", "Adnan", "Kovač", "CL-000003", cities["Mostar"], Roles.Member);
        await CreateUserAsync(userManager, "emir", "Emir", "Softić", "CL-000004", cities["Tuzla"], Roles.Member);
        await CreateUserAsync(userManager, "amra", "Amra", "Begić", "CL-000005", cities["Sarajevo"], Roles.Member);
        await CreateUserAsync(userManager, "tarik", "Tarik", "Delić", "CL-000006", cities["Banja Luka"], Roles.Member);
        await CreateUserAsync(userManager, "sara", "Sara", "Marić", "CL-000007", cities["Mostar"], Roles.Member);
    }

    private static async Task CreateUserAsync(
    UserManager<ApplicationUser> userManager,
    string userName,
    string firstName,
    string lastName,
    string membershipNumber,
    int cityId,
    string role)
    {
        if (await userManager.FindByNameAsync(userName) != null)
        {
            return;
        }

        var user = new ApplicationUser
        {
            UserName = userName,
            Email = $"{userName}@ebiblioteka.local",
            EmailConfirmed = true,
            FirstName = firstName,
            LastName = lastName,
            MembershipNumber = membershipNumber,
            CityId = cityId,
            CreatedAt = DateTime.UtcNow
        };

        var result = await userManager.CreateAsync(user, "test");
        if (!result.Succeeded)
        {
            var errors = string.Join(", ", result.Errors.Select(e => e.Description));
            throw new InvalidOperationException($"Neuspjelo kreiranje korisnika '{userName}': {errors}");
        }

        await userManager.AddToRoleAsync(user, role);
    }
    private static async Task SeedRolesAsync(IServiceProvider services)
    {
        var roleManager = services.GetRequiredService<RoleManager<IdentityRole<int>>>();

        foreach (var role in new[] { Roles.Administrator, Roles.Member })
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new IdentityRole<int>(role));
            }
        }
    }

    private static async Task SeedLookupsAsync(AppDbContext db)
    {
        if (await db.Countries.AnyAsync())
        {
            return;
        }

        db.Countries.AddRange(
            new Country { Name = "Bosna i Hercegovina" },
            new Country { Name = "Hrvatska" },
            new Country { Name = "Srbija" },
            new Country { Name = "Rusija" },
            new Country { Name = "Velika Britanija" },
            new Country { Name = "Kolumbija" },
            new Country { Name = "Njemačka" });
        await db.SaveChangesAsync();

        var countries = await db.Countries.ToDictionaryAsync(c => c.Name, c => c.Id);

        db.Cities.AddRange(
            new City { Name = "Mostar", CountryId = countries["Bosna i Hercegovina"] },
            new City { Name = "Sarajevo", CountryId = countries["Bosna i Hercegovina"] },
            new City { Name = "Tuzla", CountryId = countries["Bosna i Hercegovina"] },
            new City { Name = "Banja Luka", CountryId = countries["Bosna i Hercegovina"] },
            new City { Name = "Zagreb", CountryId = countries["Hrvatska"] },
            new City { Name = "Beograd", CountryId = countries["Srbija"] });

        db.Categories.AddRange(
            new Category { Name = "Roman" },
            new Category { Name = "Poezija" },
            new Category { Name = "Historija" },
            new Category { Name = "Nauka" },
            new Category { Name = "Dječija književnost" },
            new Category { Name = "Biografija" });
        await db.SaveChangesAsync();

        var cities = await db.Cities.ToDictionaryAsync(c => c.Name, c => c.Id);

        db.Publishers.AddRange(
            new Publisher { Name = "Svjetlost", CityId = cities["Sarajevo"] },
            new Publisher { Name = "Buybook", CityId = cities["Sarajevo"] },
            new Publisher { Name = "Zora", CityId = cities["Zagreb"] },
            new Publisher { Name = "Laguna", CityId = cities["Beograd"] });
        await db.SaveChangesAsync();
    }
}