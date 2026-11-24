using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.Data.Enums;
using Microsoft.EntityFrameworkCore;

namespace eBiblioteka.Api.Data;

// Početna aktivnost članova: historija posudbi i ocjena (podloga za preporuke),
// te po jedan primjer svakog stanja (kasni, zakasnina, rezervacije) za demonstraciju.
public static partial class DbSeeder
{
    private sealed record SeedReading(string User, string Book, int DaysAgo, int? Rating, string? Comment = null);

    private static async Task SeedActivityAsync(AppDbContext db)
    {
        if (await db.Loans.AnyAsync() || await db.Reservations.AnyAsync())
        {
            return;
        }

        var users = await db.Users.ToDictionaryAsync(u => u.UserName!, u => u.Id);
        var books = await db.Books.ToDictionaryAsync(b => b.Title, b => b.Id);
        var admin = users["desktop"];
        var now = DateTime.UtcNow;

        // Vraćene posudbe s ocjenom (zadržavanje knjige: 10 dana, rok je 14).
        var readings = new[]
        {
            // Lejla voli domaće klasike, a distopiju ne.
            new SeedReading("mobile", "Na Drini ćuprija", 60, 5, "Veličanstven roman o mostu i ljudima."),
            new SeedReading("mobile", "Prokleta avlija", 45, 5),
            new SeedReading("mobile", "Derviš i smrt", 30, 4),
            new SeedReading("mobile", "1984", 20, 2),

            new SeedReading("maja", "Na Drini ćuprija", 70, 5),
            new SeedReading("maja", "Travnička hronika", 55, 5),
            new SeedReading("maja", "Derviš i smrt", 40, 5, "Knjiga koja se pamti."),
            new SeedReading("maja", "Tvrđava", 25, 5),
            new SeedReading("maja", "Sto godina samoće", 15, 3),
            new SeedReading("maja", "Kratka historija vremena", 12, 2),

            new SeedReading("adnan", "Prokleta avlija", 65, 4),
            new SeedReading("adnan", "Derviš i smrt", 50, 5),
            new SeedReading("adnan", "Tvrđava", 35, 5),
            new SeedReading("adnan", "1984", 28, 2),
            new SeedReading("adnan", "Životinjska farma", 21, 2),
            new SeedReading("adnan", "Kratka historija vremena", 14, 3),

            // Emir i Tarik vole distopiju i popularnu nauku.
            new SeedReading("emir", "1984", 80, 5),
            new SeedReading("emir", "Životinjska farma", 62, 5),
            new SeedReading("emir", "Kratka historija vremena", 44, 5, "Teško, ali vrijedi truda."),
            new SeedReading("emir", "Bosna: kratka historija", 30, 4),
            new SeedReading("emir", "Orlovi rano lete", 18, 3),
            new SeedReading("emir", "Derviš i smrt", 9, 2),

            new SeedReading("amra", "Na Drini ćuprija", 75, 4),
            new SeedReading("amra", "Prokleta avlija", 58, 5),
            new SeedReading("amra", "Travnička hronika", 42, 5),
            new SeedReading("amra", "Kameni spavač", 26, 5, "Poezija koja ostaje."),
            new SeedReading("amra", "Dnevnik Ane Frank", 12, 3),
            new SeedReading("amra", "Životinjska farma", 6, 2),

            new SeedReading("tarik", "Kratka historija vremena", 68, 5),
            new SeedReading("tarik", "1984", 52, 4),
            new SeedReading("tarik", "Bosna: kratka historija", 36, 5),
            new SeedReading("tarik", "Tvrđava", 22, 2),
            new SeedReading("tarik", "Prokleta avlija", 16, 2),

            new SeedReading("sara", "Orlovi rano lete", 66, 5),
            new SeedReading("sara", "Ježeva kućica", 48, 5),
            new SeedReading("sara", "Dnevnik Ane Frank", 33, 5),
            new SeedReading("sara", "Ana Karenjina", 19, 4),
            new SeedReading("sara", "Sto godina samoće", 10, 5)
        };

        foreach (var reading in readings)
        {
            var borrowed = now.AddDays(-reading.DaysAgo);
            var returned = borrowed.AddDays(10);

            var loan = new Loan
            {
                UserId = users[reading.User],
                BookId = books[reading.Book],
                LoanDate = borrowed,
                DueDate = borrowed.AddDays(14),
                ReturnDate = returned,
                Status = LoanStatus.Returned
            };
            db.Loans.Add(loan);

            if (reading.Rating != null)
            {
                db.Reviews.Add(new Review
                {
                    Loan = loan,
                    UserId = loan.UserId,
                    BookId = loan.BookId,
                    Rating = reading.Rating.Value,
                    Comment = reading.Comment,
                    CreatedAt = returned.AddDays(1)
                });
            }
        }

        // Aktivne posudbe: jedna uredna (mobile) i jedna koja kasni (adnan).
        db.Loans.Add(NewActiveLoan(users["mobile"], books["Kameni spavač"], now.AddDays(-3)));
        db.Loans.Add(NewActiveLoan(users["adnan"], books["Grobnica za Borisa Davidoviča"], now.AddDays(-17)));

        // Zakasnina koja čeka uplatu (maja): vraćeno 17 dana nakon roka = 8,50 KM.
        var majaBorrowed = now.AddDays(-48);
        var majaLoan = new Loan
        {
            UserId = users["maja"],
            BookId = books["Ana Karenjina"],
            LoanDate = majaBorrowed,
            DueDate = majaBorrowed.AddDays(14),
            ReturnDate = now.AddDays(-17),
            Status = LoanStatus.Returned
        };
        db.Loans.Add(majaLoan);
        db.Fines.Add(new Fine
        {
            Loan = majaLoan,
            UserId = users["maja"],
            DaysLate = 17,
            Amount = 8.50m,
            Status = FineStatus.Unpaid,
            CreatedAt = now.AddDays(-17)
        });

        // Plaćena zakasnina na šalteru (mobile): 9 dana kašnjenja = 4,50 KM.
        var lejlaBorrowed = now.AddDays(-33);
        var lejlaLoan = new Loan
        {
            UserId = users["mobile"],
            BookId = books["Životinjska farma"],
            LoanDate = lejlaBorrowed,
            DueDate = lejlaBorrowed.AddDays(14),
            ReturnDate = now.AddDays(-10),
            Status = LoanStatus.Returned
        };
        db.Loans.Add(lejlaLoan);
        var paidFine = new Fine
        {
            Loan = lejlaLoan,
            UserId = users["mobile"],
            DaysLate = 9,
            Amount = 4.50m,
            Status = FineStatus.Paid,
            CreatedAt = now.AddDays(-10),
            PaidAt = now.AddDays(-9)
        };
        db.Fines.Add(paidFine);
        db.Payments.Add(new Payment
        {
            Fine = paidFine,
            Method = PaymentMethod.Counter,
            Status = PaymentStatus.Completed,
            AmountKm = 4.50m,
            CreatedAt = now.AddDays(-9),
            CompletedAt = now.AddDays(-9)
        });

        // Rezervacije: na čekanju za nedostupnu knjigu (emir), potvrđena (amra) i na čekanju iza nje (sara),
        // te istekla (tarik) s izvršiocem Sistem.
        db.Reservations.Add(NewReservation(users["emir"], books["Grobnica za Borisa Davidoviča"],
            ReservationStatus.Pending, now.AddDays(-2), null,
            (null, ReservationStatus.Pending, now.AddDays(-2), users["emir"], null)));

        db.Reservations.Add(NewReservation(users["amra"], books["Povratak Filipa Latinovicza"],
            ReservationStatus.Confirmed, now.AddDays(-1), now.AddHours(-20).AddDays(3),
            (null, ReservationStatus.Pending, now.AddDays(-1), users["amra"], null),
            (ReservationStatus.Pending, ReservationStatus.Confirmed, now.AddHours(-20), admin, null)));

        db.Reservations.Add(NewReservation(users["sara"], books["Povratak Filipa Latinovicza"],
            ReservationStatus.Pending, now.AddHours(-6), null,
            (null, ReservationStatus.Pending, now.AddHours(-6), users["sara"], null)));

        db.Reservations.Add(NewReservation(users["tarik"], books["Tvrđava"],
            ReservationStatus.Cancelled, now.AddDays(-6), null,
            (null, ReservationStatus.Pending, now.AddDays(-6), users["tarik"], null),
            (ReservationStatus.Pending, ReservationStatus.Confirmed, now.AddDays(-5), admin, null),
            (ReservationStatus.Confirmed, ReservationStatus.Cancelled, now.AddDays(-2), null,
                "Istekao je rok preuzimanja.")));

        // Obavijesti za testne članove.
        db.Notifications.AddRange(
            NewNotification(users["mobile"], "Dobrodošli u eBiblioteku",
                "Vaš račun je aktivan. Pregledajte katalog i rezervišite knjigu.", now.AddDays(-60), true),
            NewNotification(users["mobile"], "Knjiga posuđena",
                $"Posudili ste knjigu \"Kameni spavač\". Rok povrata je {now.AddDays(11):dd.MM.yyyy}.",
                now.AddDays(-3), false),
            NewNotification(users["maja"], "Zakasnina",
                "Knjiga \"Ana Karenjina\" vraćena je s kašnjenjem od 17 dana. Zakasnina: 8.50 KM.",
                now.AddDays(-17), false),
            NewNotification(users["amra"], "Rezervacija potvrđena",
                $"Knjiga \"Povratak Filipa Latinovicza\" čeka vas do {now.AddHours(-20).AddDays(3):dd.MM.yyyy}.",
                now.AddHours(-20), false));

        // Sve se upisuje zajedno, u jednoj transakciji.
        await db.SaveChangesAsync();
    }

    private static Loan NewActiveLoan(int userId, int bookId, DateTime borrowed) => new()
    {
        UserId = userId,
        BookId = bookId,
        LoanDate = borrowed,
        DueDate = borrowed.AddDays(14),
        Status = LoanStatus.Active
    };

    private static Reservation NewReservation(
        int userId,
        int bookId,
        ReservationStatus status,
        DateTime createdAt,
        DateTime? pickupDeadline,
        params (ReservationStatus? From, ReservationStatus To, DateTime At, int? By, string? Reason)[] history)
    {
        var reservation = new Reservation
        {
            UserId = userId,
            BookId = bookId,
            Status = status,
            CreatedAt = createdAt,
            PickupDeadline = pickupDeadline
        };

        foreach (var entry in history)
        {
            reservation.StatusHistory.Add(new ReservationStatusHistory
            {
                FromStatus = entry.From,
                ToStatus = entry.To,
                ChangedAt = entry.At,
                ChangedByUserId = entry.By,
                Reason = entry.Reason
            });
        }

        return reservation;
    }

    private static Notification NewNotification(int userId, string title, string text, DateTime createdAt, bool isRead) =>
        new()
        {
            UserId = userId,
            Title = title,
            Text = text,
            CreatedAt = createdAt,
            IsRead = isRead
        };
}
