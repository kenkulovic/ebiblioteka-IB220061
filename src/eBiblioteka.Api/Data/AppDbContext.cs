using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Data.Enums;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Data;

public class AppDbContext : IdentityDbContext<ApplicationUser, IdentityRole<int>, int>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<Country> Countries => Set<Country>();
    public DbSet<City> Cities => Set<City>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<Publisher> Publishers => Set<Publisher>();
    public DbSet<Author> Authors => Set<Author>();
    public DbSet<Book> Books => Set<Book>();
    public DbSet<BookAuthor> BookAuthors => Set<BookAuthor>();
    public DbSet<Reservation> Reservations => Set<Reservation>();
    public DbSet<ReservationStatusHistory> ReservationStatusHistory => Set<ReservationStatusHistory>();
    public DbSet<Loan> Loans => Set<Loan>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<Fine> Fines => Set<Fine>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<News> News => Set<News>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<BookSimilarity> BookSimilarities => Set<BookSimilarity>();

    // SQL Server ne pamti vremensku zonu, pa se svaki datum pri čitanju označava kao UTC.
    // Tako se u JSON-u šalje s oznakom "Z" i klijenti ga ispravno pretvaraju u lokalno vrijeme.
    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        configurationBuilder.Properties<DateTime>().HaveConversion<UtcDateTimeConverter>();
        configurationBuilder.Properties<DateTime?>().HaveConversion<NullableUtcDateTimeConverter>();
    }

    protected override void OnModelCreating(ModelBuilder b)
    {
        base.OnModelCreating(b);

        // Brisanje zapisa koje koriste drugi zapisi je zabranjeno (Restrict).
        var entityNamespace = typeof(Book).Namespace;
        foreach (var fk in b.Model.GetEntityTypes()
                     .Where(e => e.ClrType.Namespace == entityNamespace)
                     .SelectMany(e => e.GetForeignKeys()))
        {
            fk.DeleteBehavior = DeleteBehavior.Restrict;
        }

        // Šifarnici: naziv je jedinstven.
        b.Entity<Country>(e =>
        {
            e.Property(x => x.Name).IsRequired().HasMaxLength(100);
            e.HasIndex(x => x.Name).IsUnique();
        });
        b.Entity<City>(e =>
        {
            e.Property(x => x.Name).IsRequired().HasMaxLength(100);
            e.HasIndex(x => x.Name).IsUnique();
        });
        b.Entity<Category>(e =>
        {
            e.Property(x => x.Name).IsRequired().HasMaxLength(100);
            e.HasIndex(x => x.Name).IsUnique();
        });
        b.Entity<Publisher>(e =>
        {
            e.Property(x => x.Name).IsRequired().HasMaxLength(150);
            e.HasIndex(x => x.Name).IsUnique();
        });

        b.Entity<ApplicationUser>(e =>
        {
            e.Property(x => x.FirstName).IsRequired().HasMaxLength(50);
            e.Property(x => x.LastName).IsRequired().HasMaxLength(50);
            e.Property(x => x.MembershipNumber).IsRequired().HasMaxLength(20);
            e.Property(x => x.BlockReason).HasMaxLength(500);
            e.HasIndex(x => x.MembershipNumber).IsUnique();
        });

        b.Entity<Author>(e =>
        {
            e.Property(x => x.FirstName).IsRequired().HasMaxLength(50);
            e.Property(x => x.LastName).IsRequired().HasMaxLength(50);
            e.Property(x => x.Biography).HasMaxLength(1000);
        });

        b.Entity<Book>(e =>
        {
            e.Property(x => x.Title).IsRequired().HasMaxLength(200);
            e.Property(x => x.Description).HasMaxLength(2000);
            e.ToTable(t => t.HasCheckConstraint("CK_Books_TotalCopies", "[TotalCopies] >= 1"));
        });

        // Veza knjiga-autor: složeni ključ, a brisanje knjige briše i njene veze.
        b.Entity<BookAuthor>(e =>
        {
            e.HasKey(x => new { x.BookId, x.AuthorId });
            e.HasOne(x => x.Book).WithMany(x => x.BookAuthors)
                .HasForeignKey(x => x.BookId).OnDelete(DeleteBehavior.Cascade);
        });

        // Najviše jedna otvorena rezervacija po članu i knjizi.
        b.Entity<Reservation>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.BookId })
                .IsUnique()
                .HasFilter($"[Status] IN ({(int)ReservationStatus.Pending}, {(int)ReservationStatus.Confirmed})");
        });

        b.Entity<ReservationStatusHistory>(e =>
        {
            e.Property(x => x.Reason).HasMaxLength(500);
        });

        // Najviše jedna aktivna posudba po članu i knjizi.
        b.Entity<Loan>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.BookId })
                .IsUnique()
                .HasFilter($"[Status] = {(int)LoanStatus.Active}");
        });

        // Jedna ocjena po posudbi, ocjena 1-5.
        b.Entity<Review>(e =>
        {
            e.Property(x => x.Comment).HasMaxLength(500);
            e.HasIndex(x => x.LoanId).IsUnique();
            e.ToTable(t => t.HasCheckConstraint("CK_Reviews_Rating", "[Rating] BETWEEN 1 AND 5"));
        });

        // Jedna zakasnina po posudbi. Novac je decimal(10,2).
        b.Entity<Fine>(e =>
        {
            e.Property(x => x.Amount).HasPrecision(10, 2);
            e.HasIndex(x => x.LoanId).IsUnique();
        });

        b.Entity<Payment>(e =>
        {
            e.Property(x => x.AmountKm).HasPrecision(10, 2);
            e.Property(x => x.AmountEur).HasPrecision(10, 2);
            e.Property(x => x.RefundedAmountEur).HasPrecision(10, 2);
            e.Property(x => x.ExchangeRate).HasPrecision(10, 5);
            e.Property(x => x.PayPalOrderId).HasMaxLength(64);
            e.Property(x => x.PayPalCaptureId).HasMaxLength(64);
            e.Property(x => x.RefundReason).HasMaxLength(500);
            e.HasIndex(x => x.PayPalOrderId);
        });

        b.Entity<News>(e =>
        {
            e.Property(x => x.Title).IsRequired().HasMaxLength(100);
            e.Property(x => x.Text).IsRequired().HasMaxLength(2000);
        });

        b.Entity<Notification>(e =>
        {
            e.Property(x => x.Title).IsRequired().HasMaxLength(100);
            e.Property(x => x.Text).IsRequired().HasMaxLength(500);
            e.HasIndex(x => new { x.UserId, x.IsRead });
        });

        // Dva strana ključa ka istoj tabeli (Books) pa ih navodimo eksplicitno.
        b.Entity<BookSimilarity>(e =>
        {
            e.HasKey(x => new { x.BookId, x.SimilarBookId });
            e.HasOne(x => x.Book).WithMany().HasForeignKey(x => x.BookId);
            e.HasOne(x => x.SimilarBook).WithMany().HasForeignKey(x => x.SimilarBookId);
        });
    }
}