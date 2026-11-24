// Ugovorni test protiv ziv API-ja: svaki endpoint se pozove i odgovor se parsira u model.
// Pokrece se samo kad je zadana adresa:  $env:API_BASE_URL="http://localhost:5028"; dart test
import 'dart:io';

import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:test/test.dart';

final baseUrl = Platform.environment['API_BASE_URL'] ?? '';

void main() {
  if (baseUrl.isEmpty) {
    test('ugovorni test preskocen (nije zadan API_BASE_URL)', () {}, skip: 'zadajte varijablu API_BASE_URL');
    return;
  }

  late LibraryApi admin;
  late LibraryApi member;

  setUpAll(() async {
    admin = LibraryApi(ApiClient(baseUrl: baseUrl));
    member = LibraryApi(ApiClient(baseUrl: baseUrl));
    expect((await admin.login('desktop', 'test')).isAdministrator, isTrue);
    expect((await member.login('mobile', 'test')).isMember, isTrue);
  });

  test('katalog, detalji, slicne knjige i naslovnica', () async {
    final books = await member.books(pageSize: 50);
    expect(books.totalCount, greaterThan(10));
    expect(books.items.first.authors, isNotEmpty);

    final details = await member.book(books.items.first.id);
    expect(details.title, books.items.first.title);

    final cover = await member.client.getBytes('/api/books/${details.id}/cover');
    expect(cover.length, greaterThan(100));

    final similar = await member.similarBooks(details.id);
    expect(similar, isA<List<SimilarBook>>());
  });

  test('preporuke imaju objasnjenje', () async {
    final recommendations = await member.recommendations(count: 5);
    expect(recommendations, isNotEmpty);
    expect(recommendations.first.explanation, isNotEmpty);
  });

  test('sifarnici', () async {
    expect((await admin.lookups('countries')).items, isNotEmpty);
    expect((await admin.lookups('categories')).items, isNotEmpty);
    expect((await admin.cities()).items, isNotEmpty);
    expect((await admin.publishers()).items, isNotEmpty);
    expect((await admin.authors()).items, isNotEmpty);
  });

  test('clanovi, rezervacije, posudbe i zakasnine (admin)', () async {
    final members = await admin.members(pageSize: 50);
    expect(members.totalCount, greaterThanOrEqualTo(7));

    final reservations = await admin.reservations(pageSize: 50);
    expect(reservations.items, isNotEmpty);
    final details = await admin.reservation(reservations.items.first.id);
    expect(details.history, isNotEmpty);

    expect((await admin.loans(filter: 'Overdue')).items, isA<List<Loan>>());
    expect((await admin.fines()).items, isNotEmpty);
  });

  test('moje stvari (clan)', () async {
    expect((await member.myLoans()).items, isNotEmpty);
    expect((await member.myReservations()).items, isA<List<Reservation>>());
    expect((await member.myFines()).items, isA<List<Fine>>());
    expect((await member.myReviews()).items, isNotEmpty);
    expect((await member.notifications()).items, isA<List<AppNotification>>());
    expect(await member.unreadCount(), greaterThanOrEqualTo(0));
    expect((await member.me()).membershipNumber, startsWith('CL-'));
  });

  test('vijesti sa slikom', () async {
    final news = await member.news();
    expect(news.items, isNotEmpty);
    final image = await member.client.getBytes('/api/news/${news.items.first.id}/image');
    expect(image.length, greaterThan(100));
  });

  test('izvjestaji i PDF', () async {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 120));

    final loans = await admin.loanReport(from, to);
    expect(loans.totalLoans, greaterThan(0));
    expect(loans.topBooks, isNotEmpty);

    final fines = await admin.fineReport(from, to);
    expect(fines.totalFines, greaterThan(0));

    // Izvještaj o posudbama: najviše 10 knjiga, s prosječnom ocjenom; filter po kategoriji.
    expect(loans.topBooks.length, lessThanOrEqualTo(10));
    expect(loans.topBooks.any((b) => b.averageRating != null), isTrue);
    final categories = await admin.lookups('categories', pageSize: 100);
    final byCategory = await admin.loanReport(from, to, categoryId: categories.items.first.id);
    expect(byCategory.categoryName, categories.items.first.name);
    expect(byCategory.totalLoans, lessThanOrEqualTo(loans.totalLoans));

    // Izvještaj o zakasninama: lista članova, prosječno kašnjenje i filter po statusu.
    expect(fines.members, isNotEmpty);
    expect(fines.averageDaysLate, isNotNull);
    final unpaid = await admin.fineReport(from, to, status: 'Unpaid');
    expect(unpaid.paid.count, 0);
    expect(unpaid.totalFines, fines.unpaid.count);

    final pdf = await admin.loanReportPdf(from, to);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect((await admin.fineReportPdf(from, to)).length, greaterThan(1000));
    expect((await admin.loanReportPdf(from, to, categoryId: categories.items.first.id)).length, greaterThan(1000));
    expect((await admin.fineReportPdf(from, to, status: 'Paid')).length, greaterThan(1000));
  });

  test('provjere pravila, pregled povrata, filteri i brojaci upotrebe', () async {
    // Dostupnost: sve / dostupne / nedostupne.
    final all = await admin.books(pageSize: 50);
    final available = await admin.books(pageSize: 50, available: true);
    final unavailable = await admin.books(pageSize: 50, available: false);
    expect(available.totalCount + unavailable.totalCount, all.totalCount);
    expect(available.items.every((b) => b.availableCopies > 0), isTrue);
    expect(unavailable.items.every((b) => b.availableCopies == 0), isTrue);

    // Brojaci upotrebe u sifarnicima.
    final categories = await admin.lookups('categories', pageSize: 100);
    expect(categories.items.any((c) => c.usageCount > 0), isTrue);

    // Filter clanova po gradu i historija jednog clana.
    final members = await admin.members(pageSize: 50);
    final first = members.items.firstWhere((m) => m.activeLoans > 0);
    final inCity = await admin.members(cityId: first.cityId, pageSize: 50);
    expect(inCity.items.every((m) => m.cityId == first.cityId), isTrue);
    final loans = await admin.loans(userId: first.id, pageSize: 50);
    expect(loans.items, isNotEmpty);
    expect(loans.items.every((l) => l.userId == first.id), isTrue);

    // Provjera pravila prije izdavanja i pregled povrata.
    final active = loans.items.firstWhere((l) => l.isActive);
    final check = await admin.issueCheck(first.id, active.bookId);
    expect(check.canIssue, isFalse);
    expect(check.problems, isNotEmpty);
    final preview = await admin.returnPreview(active.id);
    expect(preview.daysLate, greaterThanOrEqualTo(0));

    // Provjera rezervacije za clana: knjiga koju vec ima posudjenu ne moze se rezervisati.
    final mine = await member.myLoans(pageSize: 50);
    final borrowed = mine.items.firstWhere((l) => l.isActive);
    final reserve = await member.reserveCheck(borrowed.bookId);
    expect(reserve.canReserve, isFalse);
    expect(reserve.reason, isNotNull);
  });

  test('greske servera stizu kao ApiException s porukom', () async {
    await expectLater(
      () => member.createReservation(999999),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
    await expectLater(
      () => admin.deleteLookup('countries', 1),
      throwsA(isA<ApiException>().having((e) => e.message, 'poruka', contains('ne može obrisati'))),
    );
    await expectLater(
      () => LibraryApi(ApiClient(baseUrl: baseUrl)).login('desktop', 'kriva'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });
}
