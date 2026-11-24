// Integracijski test na Android emulatoru protiv zivog API-ja (+ Worker, Mailpit i lazni PayPal).
// Pripremu okruzenja radi skripta: ../scripts/run-mobile-tests.ps1
//   flutter test integration_test/app_test.dart -d <emulator> --dart-define=API_BASE_URL=http://10.0.2.2:5028
import 'dart:convert';
import 'dart:io';

import 'package:ebiblioteka_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Adresa Mailpita na racunaru, gledano iz emulatora (10.0.2.2 je racunar).
const mailpitUrl = 'http://10.0.2.2:8025';

Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Nije pronadjeno u predvidjenom vremenu: $finder\nNa ekranu: ${visibleTexts(tester)}');
}

/// Tekstovi koji su trenutno prikazani: olaksava otkrivanje zasto test nije nasao ono sto trazi.
String visibleTexts(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .where((t) => t.isNotEmpty)
      .take(45)
      .toList();
  final fields = tester.widgetList<EditableText>(find.byType(EditableText)).map((e) => '[${e.controller.text}]');
  return '${texts.join(' | ')}  ##polja: ${fields.join(' ')}';
}

Future<void> waitGone(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Jos je prikazano nakon cekanja: $finder');
}

Future<void> settle(WidgetTester tester, [int ms = 700]) async => tester.pump(Duration(milliseconds: ms));

final _verticalScrollable = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical);

/// Pomjera ekran dok element ne postane vidljiv (dugmad na dnu duzih ekrana).
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: _verticalScrollable.first, maxScrolls: 30);
  await settle(tester, 300);
}

/// Upisuje tekst direktno u kontroler polja. tester.enterText na stvarnom uredjaju ne mijenja polje koje je vec
/// izgubilo fokus (npr. nakon prikaza greske validacije), pa se vrijednost zadaje bez tastature.
Future<void> setText(WidgetTester tester, Finder field, String text) async {
  final editable = tester.widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)));
  editable.controller.text = text;
  await tester.pump(const Duration(milliseconds: 100));
}

/// Povratak na prethodni ekran dugmetom u gornjoj traci (tester.pageBack trazi Cupertino dugme).
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton).last);
  await settle(tester);
}

/// Dodir elementa koji moze biti ispod vidljivog dijela ekrana.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  // Tastatura se spusta s animacijom i mijenja raspored: prvo se zatvori, pa se dugme trazi.
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, 800);
  await scrollTo(tester, finder);
  await tester.tap(finder);
}

Future<void> startApp(WidgetTester tester) async {
  await tester.pumpWidget(const app.EBibliotekaApp());
  await settle(tester);
}

Future<void> login(WidgetTester tester, String user, String password) async {
  await setText(tester, find.widgetWithText(TextFormField, 'Korisničko ime'), user);
  await setText(tester, find.widgetWithText(TextFormField, 'Lozinka'), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await settle(tester);
}

Future<void> openLibraryTab(WidgetTester tester, String label) async {
  await openTab(tester, 'Moje knjige');
  await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text(label)));
  await settle(tester);
}

Future<void> logout(WidgetTester tester) async {
  await openTab(tester, 'Profil');
  await scrollTo(tester, find.text('Odjava'));
  await tester.tap(find.text('Odjava'));
  await waitFor(tester, find.widgetWithText(FilledButton, 'Prijavi se'));
}

/// Najnoviji kod za reset lozinke iz e-maila (Mailpit prima poruke koje salje Worker).
Future<String> latestResetCode(String email) async {
  final client = HttpClient();
  try {
    for (var i = 0; i < 40; i++) {
      final request = await client.getUrl(Uri.parse('$mailpitUrl/api/v1/messages'));
      final body = await (await request.close()).transform(utf8.decoder).join();
      final messages = (jsonDecode(body) as Map<String, dynamic>)['messages'] as List<dynamic>;

      for (final m in messages.cast<Map<String, dynamic>>()) {
        final to = (m['To'] as List<dynamic>).map((t) => (t as Map<String, dynamic>)['Address']);
        if (to.contains(email) && (m['Subject'] as String).contains('kod za promjenu lozinke')) {
          final detail = await (await client.getUrl(Uri.parse('$mailpitUrl/api/v1/message/${m['ID']}'))).close();
          final text = (jsonDecode(await detail.transform(utf8.decoder).join()) as Map<String, dynamic>)['Text'] as String;
          return RegExp(r'\d{6}').firstMatch(text)!.group(0)!;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TestFailure('E-mail s kodom nije stigao.');
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('prijava: greske i nalog bibliotekara', (tester) async {
    await startApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
    await settle(tester);
    expect(find.text('Unesite korisničko ime.'), findsOneWidget);
    expect(find.text('Unesite lozinku.'), findsOneWidget);

    await login(tester, 'mobile', 'kriva');
    await waitFor(tester, find.text('Pogrešno korisničko ime ili lozinka.'));

    await setText(tester, find.widgetWithText(TextFormField, 'Korisničko ime'), 'desktop');
    await setText(tester, find.widgetWithText(TextFormField, 'Lozinka'), 'test');
    await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
    await waitFor(tester, find.textContaining('namijenjena članovima'));
  });

  testWidgets('pocetna: vijesti i preporuke s objasnjenjem', (tester) async {
    await startApp(tester);
    await login(tester, 'mobile', 'test');

    await waitFor(tester, find.text('Dobrodošli, Lejla'));
    // Vijesti idu od najnovije: prva kartica je vidljiva bez listanja.
    await waitFor(tester, find.text('Preporuke za vas'));
    await waitFor(tester, find.textContaining('Zato što ste visoko ocijenili'));
    expect(find.text('Tvrđava'), findsOneWidget);

    // Vijest se otvara u donjem listu.
    await tester.tap(find.text('Preporuke za vas'));
    await waitFor(tester, find.textContaining('prijedloge knjiga'));
  });

  testWidgets('katalog, detalji knjige, rezervacija i otkazivanje', (tester) async {
    await startApp(tester);
    await login(tester, 'mobile', 'test');
    await waitFor(tester, find.text('Dobrodošli, Lejla'));

    await openTab(tester, 'Katalog');
    await waitFor(tester, find.text('Derviš i smrt'));

    // Pretraga po autoru.
    await tester.enterText(find.byType(TextField).first, 'Orwell');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await waitFor(tester, find.text('Životinjska farma'));
    expect(find.text('Derviš i smrt'), findsNothing);

    // Detalji (master-detail).
    await tester.tap(find.text('1984').first);
    await waitFor(tester, find.textContaining('Distopijski roman'));
    expect(find.textContaining('Dostupno primjeraka'), findsOneWidget);
    await waitFor(tester, find.text('Slične knjige'));

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Rezerviši'));
    await waitFor(tester, find.textContaining('Rezervacija je poslana'));
    await waitGone(tester, find.textContaining('Rezervacija je poslana'));

    // Ista knjiga ponovo: server odbija s razlogom.
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Rezerviši'));
    await waitFor(tester, find.textContaining('Već imate otvorenu rezervaciju'));

    await goBack(tester);
    await settle(tester);

    await openLibraryTab(tester, 'Rezervacije');
    await waitFor(tester, find.text('1984'));
    expect(find.textContaining('Na čekanju'), findsWidgets);

    await tester.tap(find.text('Otkaži'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Otkaži rezervaciju'));
    await waitFor(tester, find.text('Rezervacija je otkazana.'));
  });

  testWidgets('posudbe: produzenje i ocjenjivanje', (tester) async {
    await startApp(tester);
    await login(tester, 'mobile', 'test');
    await waitFor(tester, find.text('Dobrodošli, Lejla'));

    await openLibraryTab(tester, 'Posudbe');
    await waitFor(tester, find.text('Kameni spavač'));

    // Produzenje aktivne posudbe (samo jednom).
    await tester.tap(find.widgetWithText(OutlinedButton, 'Produži'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Produži'));
    await waitFor(tester, find.text('Posudba je produžena.'));
    await waitFor(tester, find.textContaining('(produženo)'));
    expect(find.widgetWithText(OutlinedButton, 'Produži'), findsNothing);

    // Ocjenjivanje vracene knjige koja nije ocijenjena.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Ocijeni'));
    await settle(tester);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Pošalji')).onPressed, isNull);
    await tester.tap(find.byIcon(Icons.star_border).at(3)); // 4 zvjezdice
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Pošalji'));
    await waitFor(tester, find.text('Hvala na ocjeni!'));
    await waitFor(tester, find.text('Ocijenjeno'));
  });

  testWidgets('registracija novog clana i odjava', (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch % 1000000;
    await startApp(tester);

    await tester.tap(find.text('Nemate račun? Registrujte se'));
    await waitFor(tester, find.text('Registracija'));

    // Validacija forme.
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Registruj se'));
    await settle(tester);
    expect(find.text('Unesite ime.'), findsOneWidget);

    await setText(tester, find.widgetWithText(TextFormField, 'Ime'), 'Novi');
    await setText(tester, find.widgetWithText(TextFormField, 'Prezime'), 'Testni');
    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Grad'));
    await settle(tester);
    await tester.tap(find.text('Mostar').last);
    await settle(tester);
    await setText(tester, find.widgetWithText(TextFormField, 'Korisničko ime'), 'testni$suffix');
    await setText(tester, find.widgetWithText(TextFormField, 'E-mail'), 'testni$suffix@example.com');
    await setText(tester, find.widgetWithText(TextFormField, 'Lozinka'), 'lozinka1');
    await setText(tester, find.widgetWithText(TextFormField, 'Ponovite lozinku'), 'drugacija');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Registruj se'));
    await settle(tester);
    await waitFor(tester, find.text('Lozinke se ne poklapaju.'));

    await setText(tester, find.widgetWithText(TextFormField, 'Ponovite lozinku'), 'lozinka1');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Registruj se'));

    // Registracija je i prijava; novi clan bez historije dobija popularne knjige.
    await waitFor(tester, find.text('Dobrodošli, Novi'));
    await waitFor(tester, find.textContaining('Najčešće posuđivano ovog mjeseca'));

    await logout(tester);
  });

  testWidgets('zaboravljena lozinka: kod iz e-maila, promjena i povratak lozinke', (tester) async {
    await startApp(tester);

    await tester.tap(find.text('Zaboravljena lozinka?'));
    await waitFor(tester, find.text('Zaboravljena lozinka').last);

    await setText(tester, find.widgetWithText(TextFormField, 'E-mail'), 'sara@ebiblioteka.local');
    await tester.tap(find.widgetWithText(FilledButton, 'Pošalji kod'));
    await waitFor(tester, find.text('Kod iz e-maila'));

    // Pogresan kod.
    await setText(tester, find.widgetWithText(TextFormField, 'Kod iz e-maila'), '000000');
    await setText(tester, find.widgetWithText(TextFormField, 'Nova lozinka'), 'novalozinka');
    await tester.tap(find.widgetWithText(FilledButton, 'Promijeni lozinku'));
    await waitFor(tester, find.text('Kod nije ispravan ili je istekao.'));

    // Pravi kod stize e-mailom preko RabbitMQ-a i Workera.
    final code = await latestResetCode('sara@ebiblioteka.local');
    await setText(tester, find.widgetWithText(TextFormField, 'Kod iz e-maila'), code);
    await tester.tap(find.widgetWithText(FilledButton, 'Promijeni lozinku'));
    await waitFor(tester, find.text('Lozinka je promijenjena. Prijavite se novom lozinkom.'));
    await waitFor(tester, find.widgetWithText(FilledButton, 'Prijavi se'));

    // Nova lozinka radi; zatim se vraca stara kroz profil.
    await login(tester, 'sara', 'novalozinka');
    await waitFor(tester, find.text('Dobrodošli, Sara'));

    await openTab(tester, 'Profil');
    await waitFor(tester, find.text('Moji podaci'));
    await scrollTo(tester, find.text('Promjena lozinke'));
    await tester.tap(find.text('Promjena lozinke'));
    await settle(tester);
    await setText(tester, find.widgetWithText(TextFormField, 'Trenutna lozinka'), 'pogresna');
    await setText(tester, find.widgetWithText(TextFormField, 'Nova lozinka'), 'test');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Promijeni lozinku'));
    await waitFor(tester, find.text('Trenutna lozinka nije ispravna.'));
    await waitGone(tester, find.text('Trenutna lozinka nije ispravna.'));

    await setText(tester, find.widgetWithText(TextFormField, 'Trenutna lozinka'), 'novalozinka');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Promijeni lozinku'));
    await waitFor(tester, find.text('Lozinka je promijenjena.'));
  });

  testWidgets('placanje zakasnine u aplikaciji (PayPal) i uklanjanje ogranicenja', (tester) async {
    await startApp(tester);
    await login(tester, 'maja', 'test');
    await waitFor(tester, find.text('Dobrodošli, Maja'));

    // Neplacena zakasnina blokira rezervaciju.
    await openTab(tester, 'Katalog');
    await waitFor(tester, find.text('Derviš i smrt'));
    await tester.enterText(find.byType(TextField).first, 'Orlovi');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await waitFor(tester, find.text('Orlovi rano lete'));
    await tester.tap(find.text('Orlovi rano lete'));
    await waitFor(tester, find.widgetWithText(FilledButton, 'Rezerviši'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Rezerviši'));
    await waitFor(tester, find.textContaining('neplaćena zakasnina'));
    await goBack(tester);
    await settle(tester);

    await openLibraryTab(tester, 'Zakasnine');
    await waitFor(tester, find.textContaining('Dok postoji neplaćena zakasnina'));
    expect(find.text('8,50 KM'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Plati putem PayPal-a'));
    await waitFor(tester, find.text('Iznos: 8,50 KM'));
    // 8,50 KM / 1,95583 = 4,35 EUR (iznos racuna server).
    expect(find.textContaining('4,35 EUR'), findsOneWidget);
    expect(find.byType(WebViewWidget), findsOneWidget);

    // WebView otvara stranicu za odobrenje (lazni PayPal), koja kao i pravi PayPal preusmjerava na
    // povratnu adresu. Aplikacija presrece povratak, a server potvrdjuje uplatu (capture).
    await waitFor(tester, find.text('Plaćanje je uspješno'));
    await tester.tap(find.widgetWithText(FilledButton, 'Gotovo'));
    await waitFor(tester, find.textContaining('Plaćeno'));
    expect(find.widgetWithText(FilledButton, 'Plati putem PayPal-a'), findsNothing);
    expect(find.textContaining('Dok postoji neplaćena zakasnina'), findsNothing);
  });

  testWidgets('obavijesti: lista, procitano i broj nepročitanih', (tester) async {
    await startApp(tester);
    await login(tester, 'amra', 'test');
    await waitFor(tester, find.text('Dobrodošli, Amra'));

    // Neprocitana obavijest ima brojac na kartici.
    await waitFor(tester, find.byType(Badge));
    await openTab(tester, 'Obavijesti');
    await waitFor(tester, find.text('Rezervacija potvrđena'));

    await tester.tap(find.text('Rezervacija potvrđena'));
    await waitFor(tester, find.textContaining('čeka vas do'));
    await tester.tap(find.text('Zatvori'));
    await settle(tester);
    expect(find.text('Označi sve'), findsNothing);
  });

  testWidgets('profil: izmjena podataka', (tester) async {
    await startApp(tester);
    await login(tester, 'tarik', 'test');
    await waitFor(tester, find.text('Dobrodošli, Tarik'));

    await openTab(tester, 'Profil');
    await waitFor(tester, find.text('Moji podaci'));
    expect(find.text('Član broj CL-000006'), findsOneWidget);

    // Validacija e-maila.
    await setText(tester, find.widgetWithText(TextFormField, 'E-mail'), 'nije-email');
    await tapVisible(tester, find.text('Sačuvaj podatke'));
    await settle(tester);
    expect(find.text('Unesite ispravnu e-mail adresu.'), findsOneWidget);

    // Izmjena i povratak.
    await setText(tester, find.widgetWithText(TextFormField, 'E-mail'), 'tarik.novi@ebiblioteka.local');
    await tapVisible(tester, find.text('Sačuvaj podatke'));
    await waitFor(tester, find.text('Podaci su sačuvani.'));
    await waitGone(tester, find.text('Podaci su sačuvani.'));

    await setText(tester, find.widgetWithText(TextFormField, 'E-mail'), 'tarik@ebiblioteka.local');
    await tapVisible(tester, find.text('Sačuvaj podatke'));
    await waitFor(tester, find.text('Podaci su sačuvani.'));
  });
}
