// Integracijski test: prava aplikacija na Windowsu protiv zivog API-ja.
// Pokretanje (API mora raditi, npr. docker compose up -d):
//   flutter test integration_test -d windows --dart-define=API_BASE_URL=http://localhost:5028
import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:ebiblioteka_desktop/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 25)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Nije pronadjeno u predvidjenom vremenu: $finder');
}

Future<void> waitGone(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 15)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Još je prikazano nakon čekanja: $finder');
}

Future<void> settle(WidgetTester tester, [int ms = 600]) async {
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> startApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 950);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const app.EBibliotekaApp());
  await settle(tester);
}

Future<void> login(WidgetTester tester, String user, String password) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Korisničko ime'), user);
  await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), password);
  await tester.tap(find.text('Prijavi se'));
}

Future<void> openSection(WidgetTester tester, String title) async {
  await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(title)));
  await settle(tester);
}

/// Brise probne podatke koje je ranije (neuspjelo) pokretanje testova mozda ostavilo.
Future<void> removeLeftovers() async {
  final api = LibraryApi(ApiClient(baseUrl: app.apiBaseUrl));
  await api.login('desktop', 'test');

  for (final book in (await api.books(search: 'Testna', pageSize: 50)).items) {
    await api.deleteBook(book.id);
  }
  for (final category in (await api.lookups('categories', search: 'Testna', pageSize: 50)).items) {
    await api.deleteLookup('categories', category.id);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(removeLeftovers);
  tearDownAll(removeLeftovers);

  testWidgets('prijava: pogresna lozinka i clan bez prava', (tester) async {
    await startApp(tester);

    await login(tester, 'desktop', 'kriva');
    await waitFor(tester, find.text('Pogrešno korisničko ime ili lozinka.'));

    await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), '');
    await login(tester, 'mobile', 'test');
    await waitFor(tester, find.textContaining('namijenjena bibliotekarima'));

    // Prazna polja: validacija na formi, bez poziva servera.
    await tester.enterText(find.widgetWithText(TextFormField, 'Korisničko ime'), '');
    await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), '');
    await tester.tap(find.text('Prijavi se'));
    await settle(tester);
    expect(find.text('Unesite korisničko ime.'), findsOneWidget);
    expect(find.text('Unesite lozinku.'), findsOneWidget);
  });

  testWidgets('administrator vidi sve dijelove s podacima', (tester) async {
    await startApp(tester);
    await login(tester, 'desktop', 'test');

    // Knjige (najnovije dodane su na vrhu)
    await waitFor(tester, find.text('Ukupno: 17'));

    await openSection(tester, 'Autori');
    await waitFor(tester, find.text('Ukupno: 12'));

    await openSection(tester, 'Članovi');
    await waitFor(tester, find.text('Lejla Hodžić'));
    expect(find.text('Neplaćeno'), findsOneWidget);

    await openSection(tester, 'Posudbe');
    await waitFor(tester, find.textContaining('Kasni 3'));

    await openSection(tester, 'Rezervacije');
    await waitFor(tester, find.text('Na čekanju'));
    expect(find.text('Potvrđena'), findsWidgets);
    expect(find.text('Otkazana'), findsWidgets);

    await openSection(tester, 'Zakasnine');
    await waitFor(tester, find.text('Neplaćena'));
    expect(find.text('Plaćena'), findsWidgets);
    expect(find.text('Šalter'), findsOneWidget);
    // Uplata na šalteru: povrat je onemogućen uz objašnjenje.
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Vrati uplatu')).onPressed, isNull);
    expect(find.byTooltip('Uplata na šalteru ne vraća se kroz sistem; povrat je moguć samo za PayPal uplate.'),
        findsOneWidget);

    await openSection(tester, 'Obavijesti');
    await waitFor(tester, find.text('Novo radno vrijeme'));

    await openSection(tester, 'Šifarnici');
    await waitFor(tester, find.text('Roman'));
    await tester.tap(find.text('Države'));
    await waitFor(tester, find.text('Bosna i Hercegovina'));
  });

  testWidgets('pretraga, filter i straničenje knjiga', (tester) async {
    await startApp(tester);
    await login(tester, 'desktop', 'test');
    await waitFor(tester, find.text('Ukupno: 17'));

    // Straničenje: 17 knjiga po 10 = 2 strane.
    expect(find.text('Strana 1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Sljedeća strana'));
    await waitFor(tester, find.text('Strana 2 / 2'));

    // Pretraga po autoru.
    await tester.enterText(find.byKey(const ValueKey('list-search')), 'Orwell');
    await tester.tap(find.text('Traži'));
    await waitFor(tester, find.text('1984'));
    expect(find.text('Derviš i smrt'), findsNothing);
    expect(find.text('Ukupno: 2'), findsOneWidget);
  });

  testWidgets('greske servera se prikazuju s razlogom', (tester) async {
    await startApp(tester);
    await login(tester, 'desktop', 'test');
    await waitFor(tester, find.text('Ukupno: 17'));

    // Rezervacija bez slobodnog primjerka: server odbija potvrdu.
    await openSection(tester, 'Rezervacije');
    await waitFor(tester, find.text('Na čekanju'));
    await tester.tap(find.text('Potvrdi').first);
    await waitFor(tester, find.textContaining('Nema slobodnih primjeraka'));

    // Država koju koriste gradovi i autori: brisanje je onemogućeno uz objašnjenje i broj zapisa.
    await openSection(tester, 'Šifarnici');
    await settle(tester);
    await tester.tap(find.text('Države'));
    await waitFor(tester, find.text('Bosna i Hercegovina'));
    await settle(tester);
    expect(find.text('U upotrebi'), findsOneWidget);
    final blockedDelete = find.byWidgetPredicate((w) =>
        w is IconButton && w.onPressed == null && (w.tooltip ?? '').contains('ne može se obrisati'));
    expect(blockedDelete, findsWidgets);
  });

  testWidgets('sifarnik: dodavanje, duplikat i brisanje kategorije', (tester) async {
    // Jedinstveno ime: neuspio raniji pokusaj ne smije pokvariti sljedeci.
    final categoryName = 'Testna kategorija ${DateTime.now().millisecondsSinceEpoch % 100000}';
    await startApp(tester);
    await login(tester, 'desktop', 'test');
    await waitFor(tester, find.text('Ukupno: 17'));

    await openSection(tester, 'Šifarnici');
    await tester.tap(find.text('Kategorije'));
    await settle(tester);
    await waitFor(tester, find.text('Roman'));

    final addButton = find.widgetWithText(FilledButton, 'Dodaj kategoriju');

    await tester.tap(addButton);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Naziv *'), categoryName);
    await tester.tap(find.text('Sačuvaj'));
    await waitGone(tester, find.text('Sačuvaj'));
    await waitFor(tester, find.text(categoryName));

    // Isto ime ponovo: server vraca 409 s porukom, a dijalog ostaje otvoren.
    await tester.tap(addButton);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Naziv *'), categoryName);
    await tester.tap(find.text('Sačuvaj'));
    await waitFor(tester, find.text('Kategorija s tim nazivom već postoji.'));
    await tester.tap(find.text('Otkaži'));
    await waitGone(tester, find.text('Sačuvaj'));

    // Brisanje dodane kategorije (nema knjiga): pretragom ostaje samo njen red.
    await tester.enterText(find.byKey(const ValueKey('list-search')), categoryName);
    await tester.tap(find.text('Traži'));
    await waitFor(tester, find.text('Ukupno: 1'));
    await tester.tap(find.byTooltip('Obriši'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Obriši'));
    await waitFor(tester, find.text('Obrisano.'));
    await waitFor(tester, find.text('Nema podataka.'));
  });

  testWidgets('nova knjiga: obavezna polja, dodavanje autora i brisanje', (tester) async {
    final bookTitle = 'Testna knjiga ${DateTime.now().millisecondsSinceEpoch % 100000}';
    await startApp(tester);
    await login(tester, 'desktop', 'test');
    await waitFor(tester, find.text('Ukupno: 17'));

    await tester.tap(find.text('Nova knjiga'));
    await waitFor(tester, find.text('Nova knjiga').last);

    // Bez naslova i kategorije: validacija.
    await tester.tap(find.text('Sačuvaj'));
    await settle(tester);
    expect(find.text('Naslov je obavezan.'), findsOneWidget);
    expect(find.text('Odaberite kategoriju.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Naslov *'), bookTitle);

    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Kategorija *'));
    await settle(tester);
    await tester.tap(find.text('Roman').last);
    await settle(tester);

    // Bez autora i s pogrešnom godinom: poruke ispod kontrola navode šta se očekuje.
    await tester.enterText(find.widgetWithText(TextFormField, 'Godina izdanja'), '999');
    await tester.tap(find.text('Sačuvaj'));
    await settle(tester);
    expect(find.text('Dodajte barem jednog autora.'), findsOneWidget);
    expect(find.text('Unesite godinu od 1000 do 2100.'), findsOneWidget);
    // enterText ne mijenja polje koje je izgubilo fokus, pa se godina briše preko kontrolera.
    tester
        .widget<EditableText>(find.descendant(
            of: find.widgetWithText(TextFormField, 'Godina izdanja'), matching: find.byType(EditableText)))
        .controller
        .clear();
    await settle(tester);

    // Autor se trazi na serveru.
    await tester.enterText(find.widgetWithText(TextField, 'Dodaj autora'), 'Orwe');
    await waitFor(tester, find.text('George Orwell'));
    await tester.ensureVisible(find.text('George Orwell').last);
    await settle(tester);
    await tester.tap(find.text('George Orwell').last);
    await settle(tester);
    expect(find.widgetWithText(InputChip, 'George Orwell'), findsOneWidget);

    await tester.tap(find.text('Sačuvaj'));
    await waitGone(tester, find.text('Sačuvaj'));

    // Poruka o uspjehu s nazivom, a nova knjiga je na vrhu liste.
    await waitFor(tester, find.text('Knjiga "$bookTitle" je sačuvana.'));
    await waitFor(tester, find.descendant(of: find.byType(DataTable), matching: find.text(bookTitle)));

    // Pretraga: nova knjiga je u katalogu.
    await tester.enterText(find.byKey(const ValueKey('list-search')), bookTitle);
    await tester.tap(find.text('Traži'));
    await waitFor(tester, find.text('Ukupno: 1'));
    expect(find.descendant(of: find.byType(DataTable), matching: find.text(bookTitle)), findsOneWidget);

    // Brisanje.
    await tester.tap(find.byTooltip('Obriši'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Obriši'));
    await waitFor(tester, find.text('Nema podataka.'));
  });

  testWidgets('blokiranje i odblokiranje clana', (tester) async {
    await startApp(tester);
    await login(tester, 'desktop', 'test');
    await waitFor(tester, find.text('Ukupno: 17'));

    await openSection(tester, 'Članovi');
    await waitFor(tester, find.text('Tarik Delić'));

    // Pretragom ostaje samo Tarikov red, pa je dugme "Blokiraj" jednoznačno.
    await tester.enterText(find.byKey(const ValueKey('list-search')), 'Tarik');
    await tester.tap(find.text('Traži'));
    await waitFor(tester, find.text('Ukupno: 1'));
    await tester.tap(find.widgetWithText(TextButton, 'Blokiraj'));
    await settle(tester);

    // Dijalog ima dugme "X" koje ga zatvara bez promjene.
    await tester.tap(find.byKey(const ValueKey('dialog-close')));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Blokiraj'));
    await settle(tester);

    // Razlog je obavezan: dugme je onemogućeno dok nema 10 znakova.
    final confirmButton = find.widgetWithText(FilledButton, 'Blokiraj');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'Probno blokiranje');
    await settle(tester);
    await tester.tap(confirmButton);
    await waitFor(tester, find.text('Član je blokiran.'));
    await waitFor(tester, find.text('Odblokiraj'));

    // Odblokiranje.
    await tester.tap(find.text('Odblokiraj'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Odblokiraj'));
    await waitFor(tester, find.text('Član je odblokiran.'));
  });

  testWidgets('detalji clana i pregled povrata', (tester) async {
    await startApp(tester);
    await login(tester, 'desktop', 'test');
    await waitFor(tester, find.text('Ukupno: 17'));

    // Detalji člana: lični podaci i historija po karticama.
    await openSection(tester, 'Članovi');
    await waitFor(tester, find.text('Tarik Delić'));
    await tester.enterText(find.byKey(const ValueKey('list-search')), 'Tarik');
    await tester.tap(find.text('Traži'));
    await waitFor(tester, find.text('Ukupno: 1'));
    await tester.tap(find.widgetWithText(TextButton, 'Detalji'));
    await waitFor(tester, find.text('Član: Tarik Delić'));
    expect(find.textContaining('Broj karte:'), findsOneWidget);
    // Historija ima pretragu po naslovu knjige.
    await waitFor(tester, find.byKey(const ValueKey('history-search')));
    await tester.enterText(find.byKey(const ValueKey('history-search')), 'nepostojeći naslov');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await waitFor(tester, find.text('Nema zapisa.'));
    await tester.tap(find.text('Rezervacije').last);
    await settle(tester);
    await tester.tap(find.text('Zakasnine').last);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('dialog-close')));
    await settle(tester);
    expect(find.text('Član: Tarik Delić'), findsNothing);

    // Pregled povrata prije potvrde: rok, datum povrata i zakasnina; odustajanje ne mijenja ništa.
    await openSection(tester, 'Posudbe');
    await waitFor(tester, find.widgetWithText(TextButton, 'Povrat'));
    await tester.tap(find.widgetWithText(TextButton, 'Povrat').first);
    await waitFor(tester, find.textContaining('Datum povrata:'));
    expect(find.textContaining('Rok povrata:'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Otkaži'));
    await settle(tester);
    expect(find.textContaining('Datum povrata:'), findsNothing);
  });

  testWidgets('knjiga u upotrebi, brzo dodavanje iz forme, rok povrata i preuzimanje rezervacije', (tester) async {
    await startApp(tester);
    await login(tester, 'desktop', 'test');
    await waitFor(tester, find.text('Nova knjiga'));

    // Knjiga s posudbama: brisanje je onemogućeno uz razlog.
    await tester.enterText(find.byKey(const ValueKey('list-search')), 'Derviš i smrt');
    await tester.tap(find.text('Traži'));
    await waitFor(tester, find.text('Ukupno: 1'));
    expect(
      find.byWidgetPredicate((w) =>
          w is IconButton && w.onPressed == null && (w.tooltip ?? '').contains('Knjiga se ne može obrisati')),
      findsOneWidget,
    );

    // Forma knjige: autor, kategorija i izdavač mogu se dodati iz modala.
    await tester.tap(find.text('Nova knjiga'));
    await waitFor(tester, find.byKey(const ValueKey('book-add-category')));
    for (final (key, title) in [
      ('book-add-category', 'Nova kategorija'),
      ('book-add-publisher', 'Novi izdavač'),
      ('book-add-author', 'Novi autor'),
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await settle(tester);
      expect(find.text(title), findsWidgets);
      await tester.tap(find.widgetWithText(TextButton, 'Otkaži').last);
      await settle(tester);
    }
    await tester.tap(find.widgetWithText(TextButton, 'Otkaži'));
    await settle(tester);

    // Filter posudbi po roku povrata: datum se bira iz kalendara i može se ukloniti.
    await openSection(tester, 'Posudbe');
    await waitFor(tester, find.byKey(const ValueKey('loan-due-filter')));
    await tester.tap(find.byKey(const ValueKey('loan-due-filter')));
    await settle(tester);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.byType(TextButton)).last);
    await waitFor(tester, find.textContaining('Rok do '));
    await tester.tap(find.byKey(const ValueKey('loan-due-clear')));
    await waitFor(tester, find.text('Rok povrata do'));

    // "Preuzeto" vodi na formu izdavanja s odabranom rezervacijom i provjerom pravila.
    await openSection(tester, 'Rezervacije');
    await waitFor(tester, find.widgetWithText(TextButton, 'Preuzeto'));
    await tester.tap(find.widgetWithText(TextButton, 'Preuzeto').first);
    await waitFor(tester, find.byKey(const ValueKey('issue-check')));
    expect(find.text('Izdavanje knjige'), findsOneWidget);
    expect(find.textContaining('potvrđenu rezervaciju'), findsOneWidget);
    expect(find.byKey(const ValueKey('issue-dates')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Otkaži').last);
    await settle(tester);
  });

  testWidgets('izvještaji: prikaz zbirnih podataka', (tester) async {
    await startApp(tester);
    await login(tester, 'desktop', 'test');
    await waitFor(tester, find.text('Ukupno: 17'));

    await openSection(tester, 'Izvještaji');
    await waitFor(tester, find.text('Izvještaj o posudbama'));
    expect(find.text('Izvještaj o zakasninama i uplatama'), findsOneWidget);
    expect(find.text('Izvezi u PDF'), findsNWidgets(2));
    expect(find.textContaining('10 najposuđivanijih knjiga'), findsOneWidget);
    expect(find.text('Posudbe po kategorijama'), findsOneWidget);
    expect(find.textContaining('Članovi sa zakasninama'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-category')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-status')), findsOneWidget);

    // Filter statusa: samo neplaćene zakasnine.
    await tester.tap(find.byKey(const ValueKey('report-status')));
    await settle(tester);
    await tester.tap(find.text('Neplaćene').last);
    await settle(tester);
    await waitFor(tester, find.textContaining('Članovi sa zakasninama'));
  });
}
