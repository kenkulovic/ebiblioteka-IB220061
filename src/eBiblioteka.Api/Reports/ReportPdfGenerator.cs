using eBiblioteka.Api.Data.Enums;
using eBiblioteka.Api.Dtos;
using QuestPDF.Drawing;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace eBiblioteka.Api.Reports;

// Pravi PDF izvještaje. Font DejaVu Sans se isporučuje uz aplikaciju (podrška za č, ć, đ, š, ž).
public static class ReportPdfGenerator
{
    private const string FontFamily = "DejaVu Sans";
    private static readonly string Accent = Colors.Blue.Darken3;

    static ReportPdfGenerator()
    {
        // QuestPDF Community licenca: besplatna za nekomercijalnu i akademsku upotrebu.
        QuestPDF.Settings.License = LicenseType.Community;

        var fontDirectory = Path.Combine(AppContext.BaseDirectory, "Resources", "Fonts");
        foreach (var file in new[] { "DejaVuSans.ttf", "DejaVuSans-Bold.ttf" })
        {
            using var stream = File.OpenRead(Path.Combine(fontDirectory, file));
            FontManager.RegisterFontFromStream(stream);
        }
    }

    public static byte[] Loans(LoanReportDto report, string generatedBy) =>
        Document.Create(document => document.Page(page =>
        {
            Configure(page, "Izvještaj o posudbama", report.From, report.To, generatedBy);

            page.Content().Column(column =>
            {
                column.Spacing(10);

                column.Item().Element(c => SummaryTable(c, new (string, string)[]
                {
                    ("Ukupno posudbi u periodu", report.TotalLoans.ToString()),
                    ("Vraćeno", report.Returned.ToString()),
                    ("Još aktivno", report.Active.ToString()),
                    ("Od toga kasni", report.OverdueNow.ToString()),
                    ("Prosječno trajanje (vraćene), dana",
                        report.AverageLoanDays?.ToString("0.0", System.Globalization.CultureInfo.InvariantCulture)
                            .Replace('.', ',') ?? "—")
                }));

                column.Item().Text("Najposuđivanije knjige").Bold().FontSize(11);
                column.Item().Element(c => CountTable(c, "Knjiga", report.TopBooks));

                column.Item().Text("Posudbe po kategorijama").Bold().FontSize(11);
                column.Item().Element(c => CountTable(c, "Kategorija", report.ByCategory));

                column.Item().Text("Pregled posudbi").Bold().FontSize(11);
                column.Item().Table(table =>
                {
                    table.ColumnsDefinition(c =>
                    {
                        c.ConstantColumn(62);
                        c.RelativeColumn(3);
                        c.RelativeColumn(4);
                        c.ConstantColumn(62);
                        c.ConstantColumn(78);
                    });

                    table.Header(h =>
                    {
                        foreach (var title in new[] { "Posuđeno", "Član", "Knjiga", "Rok", "Povrat" })
                        {
                            h.Cell().Element(HeaderCell).Text(title);
                        }
                    });

                    foreach (var item in report.Items)
                    {
                        table.Cell().Element(BodyCell).Text(Date(item.LoanDate));
                        table.Cell().Element(BodyCell).Text(item.Member);
                        table.Cell().Element(BodyCell).Text(item.Book);
                        table.Cell().Element(BodyCell).Text(Date(item.DueDate));
                        table.Cell().Element(BodyCell).Text(text =>
                        {
                            if (item.ReturnDate.HasValue)
                            {
                                text.Span(Date(item.ReturnDate.Value));
                            }
                            else if (item.IsOverdue)
                            {
                                text.Span("Kasni").FontColor(Colors.Red.Darken2).Bold();
                            }
                            else
                            {
                                text.Span("Aktivna");
                            }
                        });
                    }
                });

                if (report.ItemsTruncated)
                {
                    column.Item().Text("Prikazano je prvih 200 posudbi; ostale su obuhvaćene zbirnim podacima.")
                        .Italic().FontColor(Colors.Grey.Darken1);
                }
            });
        })).GeneratePdf();

    public static byte[] Fines(FineReportDto report, string generatedBy) =>
        Document.Create(document => document.Page(page =>
        {
            Configure(page, "Izvještaj o zakasninama i uplatama", report.From, report.To, generatedBy);

            page.Content().Column(column =>
            {
                column.Spacing(10);

                column.Item().Element(c => SummaryTable(c, new (string, string)[]
                {
                    ("Ukupno zakasnina u periodu", $"{report.TotalFines}  ({Money(report.TotalAmountKm)})"),
                    ("Neplaćene", $"{report.Unpaid.Count}  ({Money(report.Unpaid.AmountKm)})"),
                    ("Plaćene", $"{report.Paid.Count}  ({Money(report.Paid.AmountKm)})"),
                    ("Stornirane", $"{report.Cancelled.Count}  ({Money(report.Cancelled.AmountKm)})"),
                    ("Naplaćeno putem PayPal-a", Money(report.PaidPayPalKm)),
                    ("Naplaćeno na šalteru", Money(report.PaidCounterKm)),
                    ("Vraćene uplate", $"{report.RefundedCount}  ({Decimal(report.RefundedEur)} EUR)")
                }));

                column.Item().Text("Pregled zakasnina").Bold().FontSize(11);
                column.Item().Table(table =>
                {
                    table.ColumnsDefinition(c =>
                    {
                        c.ConstantColumn(62);
                        c.RelativeColumn(3);
                        c.RelativeColumn(4);
                        c.ConstantColumn(40);
                        c.ConstantColumn(58);
                        c.ConstantColumn(84);
                    });

                    table.Header(h =>
                    {
                        foreach (var title in new[] { "Datum", "Član", "Knjiga", "Dana", "Iznos", "Status" })
                        {
                            h.Cell().Element(HeaderCell).Text(title);
                        }
                    });

                    foreach (var item in report.Items)
                    {
                        table.Cell().Element(BodyCell).Text(Date(item.CreatedAt));
                        table.Cell().Element(BodyCell).Text(item.Member);
                        table.Cell().Element(BodyCell).Text(item.Book);
                        table.Cell().Element(BodyCell).Text(item.DaysLate.ToString());
                        table.Cell().Element(BodyCell).Text(Money(item.AmountKm));
                        table.Cell().Element(BodyCell).Text(StatusLabel(item));
                    }
                });

                if (report.ItemsTruncated)
                {
                    column.Item().Text("Prikazano je prvih 200 zakasnina; ostale su obuhvaćene zbirnim podacima.")
                        .Italic().FontColor(Colors.Grey.Darken1);
                }
            });
        })).GeneratePdf();

    private static void Configure(PageDescriptor page, string title, DateOnly from, DateOnly to, string generatedBy)
    {
        page.Size(PageSizes.A4);
        page.Margin(30);
        page.DefaultTextStyle(x => x.FontFamily(FontFamily).FontSize(9));

        page.Header().PaddingBottom(10).Column(column =>
        {
            column.Item().Text("eBiblioteka").Bold().FontSize(16).FontColor(Accent);
            column.Item().Text(title).Bold().FontSize(13);
            column.Item().Text($"Period: {from:dd.MM.yyyy} – {to:dd.MM.yyyy}")
                .FontColor(Colors.Grey.Darken2);
            column.Item().PaddingTop(4).LineHorizontal(1).LineColor(Accent);
        });

        page.Footer().Row(row =>
        {
            row.RelativeItem().Text($"Izradio: {generatedBy}, {DateTime.UtcNow:dd.MM.yyyy HH:mm} UTC")
                .FontSize(8).FontColor(Colors.Grey.Darken1);
            row.AutoItem().Text(text =>
            {
                text.DefaultTextStyle(x => x.FontSize(8).FontColor(Colors.Grey.Darken1));
                text.Span("Strana ");
                text.CurrentPageNumber();
                text.Span(" / ");
                text.TotalPages();
            });
        });
    }

    private static void SummaryTable(IContainer container, IEnumerable<(string Label, string Value)> rows) =>
        container.Border(0.5f).BorderColor(Colors.Grey.Lighten1).Table(table =>
        {
            table.ColumnsDefinition(c =>
            {
                c.RelativeColumn(3);
                c.RelativeColumn(2);
            });

            foreach (var (label, value) in rows)
            {
                table.Cell().Background(Colors.Grey.Lighten4).Padding(4).Text(label);
                table.Cell().Padding(4).Text(value).Bold();
            }
        });

    private static void CountTable(IContainer container, string firstColumn, List<CountItemDto> rows) =>
        container.Table(table =>
        {
            table.ColumnsDefinition(c =>
            {
                c.RelativeColumn(5);
                c.ConstantColumn(70);
            });

            table.Header(h =>
            {
                h.Cell().Element(HeaderCell).Text(firstColumn);
                h.Cell().Element(HeaderCell).Text("Posudbi");
            });

            if (rows.Count == 0)
            {
                table.Cell().ColumnSpan(2).Element(BodyCell).Text("Nema podataka za odabrani period.");
                return;
            }

            foreach (var row in rows)
            {
                table.Cell().Element(BodyCell).Text(row.Name);
                table.Cell().Element(BodyCell).Text(row.Count.ToString());
            }
        });

    private static IContainer HeaderCell(IContainer container) =>
        container.Background(Accent).Padding(4).DefaultTextStyle(x => x.FontColor(Colors.White).Bold());

    private static IContainer BodyCell(IContainer container) =>
        container.BorderBottom(0.5f).BorderColor(Colors.Grey.Lighten1).Padding(4);

    private static string Date(DateTime value) => value.ToString("dd.MM.yyyy");

    // Decimalni zarez, bez obzira na jezik servera.
    private static string Decimal(decimal value) =>
        value.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture).Replace('.', ',');

    private static string Money(decimal value) => $"{Decimal(value)} KM";

    private static string StatusLabel(FineReportItemDto item) => item.Status switch
    {
        FineStatus.Unpaid => "Neplaćena",
        FineStatus.Paid => item.PaymentMethod == PaymentMethod.PayPal ? "Plaćena (PayPal)" : "Plaćena (šalter)",
        FineStatus.Cancelled => "Stornirana",
        _ => item.Status.ToString()
    };
}
