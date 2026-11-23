import 'dart:convert';

import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

ApiClient clientReturning(int status, Object? body, {void Function(http.Request)? onRequest}) => ApiClient(
      baseUrl: 'http://test/',
      client: MockClient((request) async {
        onRequest?.call(request);
        return http.Response.bytes(utf8.encode(body == null ? '' : jsonEncode(body)), status,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

void main() {
  group('ApiClient greske', () {
    test('uzima poruku iz odgovora servera', () async {
      final client = clientReturning(409, {'status': 409, 'message': 'Država se ne može obrisati.'});
      expect(
        () => client.delete('/api/countries/1'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Država se ne može obrisati.')
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('uzima prvu poruku validacije', () async {
      final client = clientReturning(400, {
        'title': 'One or more validation errors occurred.',
        'errors': {
          'Title': ['Naslov je obavezan.']
        }
      });
      expect(() => client.post('/api/books', body: {}),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Naslov je obavezan.')));
    });

    test('ima opcu poruku kad tijelo nije JSON', () async {
      final client = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response('<html>', 403)),
      );
      expect(() => client.get('/api/x'),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Nemate pravo za ovu radnju.')));
    });

    test('401 s tokenom javlja da je prijava istekla', () async {
      var called = false;
      final client = clientReturning(401, null)
        ..token = 'abc'
        ..onUnauthorized = () => called = true;
      await expectLater(() => client.get('/api/books'), throwsA(isA<ApiException>()));
      expect(called, isTrue);
    });

    test('401 bez tokena (pogresna prijava) ne odjavljuje', () async {
      var called = false;
      final client = clientReturning(401, {'status': 401, 'message': 'Pogrešno korisničko ime ili lozinka.'})
        ..onUnauthorized = () => called = true;
      await expectLater(() => client.post('/api/auth/login', body: {}), throwsA(isA<ApiException>()));
      expect(called, isFalse);
    });
  });

  group('ApiClient zahtjevi', () {
    test('dodaje Bearer token i izostavlja prazne parametre upita', () async {
      late http.Request seen;
      final client = clientReturning(200, {'ok': true}, onRequest: (r) => seen = r)..token = 'tok';
      await client.get('/api/books', query: {'page': 2, 'search': '', 'categoryId': null});

      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(seen.url.toString(), 'http://test/api/books?page=2');
    });

    test('204 vraca null', () async {
      final client = clientReturning(204, null);
      expect(await client.delete('/api/news/1'), isNull);
    });
  });

  group('Modeli', () {
    test('PagedResult racuna broj stranica', () {
      final page = PagedResult<Lookup>.fromJson({
        'items': [
          {'id': 1, 'name': 'Roman'}
        ],
        'totalCount': 25,
        'page': 1,
        'pageSize': 10,
      }, Lookup.fromJson);
      expect(page.totalPages, 3);
      expect(page.items.single.name, 'Roman');
    });

    test('datumi s oznakom Z postaju lokalno vrijeme', () {
      final loan = Loan.fromJson({
        'id': 1,
        'loanDate': '2026-11-23T22:19:45.0292964Z',
        'dueDate': '2026-12-07T22:19:45Z',
        'returnDate': null,
        'extensionCount': 0,
        'status': 'Active',
        'isOverdue': false,
        'daysOverdue': 0,
        'userId': 2,
        'userFullName': 'Lejla Hodžić',
        'membershipNumber': 'CL-000001',
        'bookId': 3,
        'bookTitle': 'Derviš i smrt',
        'bookHasCover': true,
        'fineId': null,
        'hasReview': false,
      });
      expect(loan.loanDate.isUtc, isFalse);
      expect(loan.loanDate.toUtc().hour, 22);
      expect(loan.returnDate, isNull);
    });
  });

  group('Formatiranje', () {
    test('iznosi imaju decimalni zarez', () {
      expect(formatKm(8.5), '8,50 KM');
      expect(formatEur(4.346), '4,35 EUR');
    });

    test('datum bez vrijednosti je crtica', () {
      expect(formatDate(null), '—');
      expect(formatDate(DateTime(2026, 3, 5)), '05.03.2026.');
    });

    test('statusi imaju bosanske nazive', () {
      expect(Labels.reservationStatus('Pending'), 'Na čekanju');
      expect(Labels.loanStatus('Active', overdue: true), 'Kasni');
      expect(Labels.fineStatus('Cancelled'), 'Stornirana');
    });
  });
}
