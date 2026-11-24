import 'dart:typed_data';

import 'api_client.dart';
import 'models.dart';

/// Svi endpointi eBiblioteka API-ja kao tipizirane metode. Koriste ih i desktop i mobilna aplikacija.
class LibraryApi {
  LibraryApi(this.client);

  final ApiClient client;

  Future<PagedResult<T>> _page<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    int page = 1,
    int pageSize = 10,
    String? search,
    Map<String, dynamic> extra = const {},
  }) async {
    final json = await client.get(path, query: {
      'page': page,
      'pageSize': pageSize,
      'search': search,
      ...extra,
    }) as Map<String, dynamic>;
    return PagedResult.fromJson(json, parse);
  }

  // ---------------------------------------------------------------- Prijava

  Future<LoginResult> login(String userName, String password) async {
    final json = await client.post('/api/auth/login', body: {'userName': userName, 'password': password});
    final result = LoginResult.fromJson(json as Map<String, dynamic>);
    client.token = result.token;
    return result;
  }

  /// Poništava token na serveru. Greška se ignoriše: korisnik se svejedno odjavljuje lokalno.
  Future<void> logout() async {
    try {
      await client.post('/api/auth/logout');
    } on ApiException {
      // Token je možda već istekao ili je server nedostupan.
    }
  }

  Future<LoginResult> register({
    required String userName,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required int cityId,
    String? phoneNumber,
  }) async {
    final json = await client.post('/api/auth/register', body: {
      'userName': userName,
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'cityId': cityId,
      if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
    });
    final result = LoginResult.fromJson(json as Map<String, dynamic>);
    client.token = result.token;
    return result;
  }

  Future<void> forgotPassword(String email) => client.post('/api/auth/forgot-password', body: {'email': email});

  Future<void> resetPassword(String email, String code, String newPassword) =>
      client.post('/api/auth/reset-password', body: {'email': email, 'code': code, 'newPassword': newPassword});

  // ------------------------------------------------------------- Sifarnici

  /// [kind] je "countries" ili "categories".
  Future<PagedResult<Lookup>> lookups(String kind, {int page = 1, int pageSize = 10, String? search}) =>
      _page('/api/$kind', Lookup.fromJson, page: page, pageSize: pageSize, search: search);

  Future<void> createLookup(String kind, String name) => client.post('/api/$kind', body: {'name': name});

  Future<void> updateLookup(String kind, int id, String name) => client.put('/api/$kind/$id', body: {'name': name});

  Future<void> deleteLookup(String kind, int id) => client.delete('/api/$kind/$id');

  Future<PagedResult<City>> cities({int page = 1, int pageSize = 10, String? search, int? countryId}) =>
      _page('/api/cities', City.fromJson,
          page: page, pageSize: pageSize, search: search, extra: {'countryId': countryId});

  Future<void> createCity(String name, int countryId) =>
      client.post('/api/cities', body: {'name': name, 'countryId': countryId});

  Future<void> updateCity(int id, String name, int countryId) =>
      client.put('/api/cities/$id', body: {'name': name, 'countryId': countryId});

  Future<void> deleteCity(int id) => client.delete('/api/cities/$id');

  Future<PagedResult<Publisher>> publishers({int page = 1, int pageSize = 10, String? search}) =>
      _page('/api/publishers', Publisher.fromJson, page: page, pageSize: pageSize, search: search);

  Future<void> createPublisher(String name, int cityId) =>
      client.post('/api/publishers', body: {'name': name, 'cityId': cityId});

  Future<void> updatePublisher(int id, String name, int cityId) =>
      client.put('/api/publishers/$id', body: {'name': name, 'cityId': cityId});

  Future<void> deletePublisher(int id) => client.delete('/api/publishers/$id');

  // ----------------------------------------------------------------- Autori

  Future<PagedResult<Author>> authors({int page = 1, int pageSize = 10, String? search}) =>
      _page('/api/authors', Author.fromJson, page: page, pageSize: pageSize, search: search);

  Map<String, dynamic> _authorBody(String firstName, String lastName, String? biography, int countryId) => {
        'firstName': firstName,
        'lastName': lastName,
        'biography': biography,
        'countryId': countryId,
      };

  Future<void> createAuthor(String firstName, String lastName, String? biography, int countryId) =>
      client.post('/api/authors', body: _authorBody(firstName, lastName, biography, countryId));

  Future<void> updateAuthor(int id, String firstName, String lastName, String? biography, int countryId) =>
      client.put('/api/authors/$id', body: _authorBody(firstName, lastName, biography, countryId));

  Future<void> deleteAuthor(int id) => client.delete('/api/authors/$id');

  // ----------------------------------------------------------------- Knjige

  Future<PagedResult<BookItem>> books({
    int page = 1,
    int pageSize = 10,
    String? search,
    int? categoryId,
    int? authorId,
    bool onlyAvailable = false,
  }) =>
      _page('/api/books', BookItem.fromJson,
          page: page,
          pageSize: pageSize,
          search: search,
          extra: {
            'categoryId': categoryId,
            'authorId': authorId,
            'onlyAvailable': onlyAvailable ? 'true' : null,
          });

  Future<BookDetails> book(int id) async =>
      BookDetails.fromJson(await client.get('/api/books/$id') as Map<String, dynamic>);

  Map<String, dynamic> bookBody({
    required String title,
    int? publishedYear,
    int? pageCount,
    String? description,
    required int totalCopies,
    required int categoryId,
    int? publisherId,
    required List<int> authorIds,
  }) =>
      {
        'title': title,
        'publishedYear': publishedYear,
        'pageCount': pageCount,
        'description': description,
        'totalCopies': totalCopies,
        'categoryId': categoryId,
        'publisherId': publisherId,
        'authorIds': authorIds,
      };

  Future<BookDetails> createBook(Map<String, dynamic> body) async =>
      BookDetails.fromJson(await client.post('/api/books', body: body) as Map<String, dynamic>);

  Future<BookDetails> updateBook(int id, Map<String, dynamic> body) async =>
      BookDetails.fromJson(await client.put('/api/books/$id', body: body) as Map<String, dynamic>);

  Future<void> deleteBook(int id) => client.delete('/api/books/$id');

  String bookCoverUrl(int id) => client.uri('/api/books/$id/cover').toString();

  Future<void> setBookCover(int id, String filename, List<int> bytes) => client.sendMultipart(
        'PUT',
        '/api/books/$id/cover',
        files: [UploadFile(field: 'file', filename: filename, bytes: bytes)],
      );

  Future<void> removeBookCover(int id) => client.delete('/api/books/$id/cover');

  Future<List<SimilarBook>> similarBooks(int bookId, {int count = 5}) async {
    final json = await client.get('/api/books/$bookId/similar', query: {'count': count}) as List<dynamic>;
    return json.map((e) => SimilarBook.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Recommendation>> recommendations({int count = 5}) async {
    final json = await client.get('/api/recommendations', query: {'count': count}) as List<dynamic>;
    return json.map((e) => Recommendation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> recalculateRecommendations() async => await client.post('/api/recommendations/recalculate') as int;

  // ----------------------------------------------------------------- Clanovi

  Future<PagedResult<Member>> members({int page = 1, int pageSize = 10, String? search, bool? isBlocked}) =>
      _page('/api/members', Member.fromJson,
          page: page, pageSize: pageSize, search: search, extra: {'isBlocked': isBlocked});

  Future<Member> member(int id) async => Member.fromJson(await client.get('/api/members/$id') as Map<String, dynamic>);

  Future<Member> me() async => Member.fromJson(await client.get('/api/members/me') as Map<String, dynamic>);

  Future<Member> updateMe({
    required String firstName,
    required String lastName,
    required String email,
    required int cityId,
    String? phoneNumber,
  }) async =>
      Member.fromJson(await client.put('/api/members/me', body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'cityId': cityId,
        'phoneNumber': phoneNumber,
      }) as Map<String, dynamic>);

  Future<void> changePassword(String current, String next) =>
      client.post('/api/members/me/change-password', body: {'currentPassword': current, 'newPassword': next});

  String memberImageUrl(int id) => client.uri('/api/members/$id/image').toString();

  Future<void> setMyImage(String filename, List<int> bytes) => client.sendMultipart(
        'PUT',
        '/api/members/me/image',
        files: [UploadFile(field: 'file', filename: filename, bytes: bytes)],
      );

  Future<void> removeMyImage() => client.delete('/api/members/me/image');

  Future<Member> blockMember(int id, String reason) async =>
      Member.fromJson(await client.post('/api/members/$id/block', body: {'reason': reason}) as Map<String, dynamic>);

  Future<Member> unblockMember(int id) async =>
      Member.fromJson(await client.post('/api/members/$id/unblock') as Map<String, dynamic>);

  // ------------------------------------------------------------- Rezervacije

  Future<Reservation> createReservation(int bookId) async =>
      Reservation.fromJson(await client.post('/api/reservations', body: {'bookId': bookId}) as Map<String, dynamic>);

  Future<PagedResult<Reservation>> myReservations({int page = 1, int pageSize = 10, String? status}) =>
      _page('/api/reservations/mine', Reservation.fromJson,
          page: page, pageSize: pageSize, extra: {'status': status});

  Future<PagedResult<Reservation>> reservations({int page = 1, int pageSize = 10, String? search, String? status}) =>
      _page('/api/reservations', Reservation.fromJson,
          page: page, pageSize: pageSize, search: search, extra: {'status': status});

  Future<Reservation> reservation(int id) async =>
      Reservation.fromJson(await client.get('/api/reservations/$id') as Map<String, dynamic>);

  Future<Reservation> confirmReservation(int id) async =>
      Reservation.fromJson(await client.post('/api/reservations/$id/confirm') as Map<String, dynamic>);

  Future<Reservation> cancelReservation(int id, {String? reason}) async =>
      Reservation.fromJson(await client.post('/api/reservations/$id/cancel', body: {'reason': reason})
          as Map<String, dynamic>);

  // ------------------------------------------------------------------ Posudbe

  Future<Loan> issueLoan({int? reservationId, int? userId, int? bookId}) async =>
      Loan.fromJson(await client.post('/api/loans',
          body: {'reservationId': reservationId, 'userId': userId, 'bookId': bookId}) as Map<String, dynamic>);

  Future<PagedResult<Loan>> loans({int page = 1, int pageSize = 10, String? search, String? filter}) =>
      _page('/api/loans', Loan.fromJson, page: page, pageSize: pageSize, search: search, extra: {'filter': filter});

  Future<PagedResult<Loan>> myLoans({int page = 1, int pageSize = 10, String? filter}) =>
      _page('/api/loans/mine', Loan.fromJson, page: page, pageSize: pageSize, extra: {'filter': filter});

  Future<Loan> returnLoan(int id) async =>
      Loan.fromJson(await client.post('/api/loans/$id/return') as Map<String, dynamic>);

  Future<Loan> extendLoan(int id) async =>
      Loan.fromJson(await client.post('/api/loans/$id/extend') as Map<String, dynamic>);

  // ---------------------------------------------------------- Zakasnine i uplate

  Future<PagedResult<Fine>> fines({int page = 1, int pageSize = 10, String? search, String? status}) =>
      _page('/api/fines', Fine.fromJson, page: page, pageSize: pageSize, search: search, extra: {'status': status});

  Future<PagedResult<Fine>> myFines({int page = 1, int pageSize = 20, String? status}) =>
      _page('/api/fines/mine', Fine.fromJson, page: page, pageSize: pageSize, extra: {'status': status});

  Future<Fine> payFineAtCounter(int id) async =>
      Fine.fromJson(await client.post('/api/fines/$id/pay-at-counter') as Map<String, dynamic>);

  Future<List<Payment>> finePayments(int fineId) async {
    final json = await client.get('/api/fines/$fineId/payments') as List<dynamic>;
    return json.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PaymentInit> startPayPalPayment(int fineId) async =>
      PaymentInit.fromJson(await client.post('/api/fines/$fineId/payments') as Map<String, dynamic>);

  Future<Payment> capturePayment(int paymentId) async =>
      Payment.fromJson(await client.post('/api/payments/$paymentId/capture') as Map<String, dynamic>);

  Future<Payment> cancelPayment(int paymentId) async =>
      Payment.fromJson(await client.post('/api/payments/$paymentId/cancel') as Map<String, dynamic>);

  Future<Payment> refundPayment(int paymentId, String reason) async =>
      Payment.fromJson(await client.post('/api/payments/$paymentId/refund', body: {'reason': reason})
          as Map<String, dynamic>);

  // ------------------------------------------------------------------- Ocjene

  Future<Review> createReview(int loanId, int rating, String? comment) async =>
      Review.fromJson(await client.post('/api/reviews',
          body: {'loanId': loanId, 'rating': rating, 'comment': comment}) as Map<String, dynamic>);

  Future<Review> updateReview(int id, int rating, String? comment) async =>
      Review.fromJson(await client.put('/api/reviews/$id', body: {'rating': rating, 'comment': comment})
          as Map<String, dynamic>);

  Future<PagedResult<Review>> bookReviews(int bookId, {int page = 1, int pageSize = 10}) =>
      _page('/api/books/$bookId/reviews', Review.fromJson, page: page, pageSize: pageSize);

  Future<PagedResult<Review>> myReviews({int page = 1, int pageSize = 20}) =>
      _page('/api/reviews/mine', Review.fromJson, page: page, pageSize: pageSize);

  // ---------------------------------------------------------------- Obavijesti

  Future<PagedResult<AppNotification>> notifications({int page = 1, int pageSize = 20, bool onlyUnread = false}) =>
      _page('/api/notifications/mine', AppNotification.fromJson,
          page: page, pageSize: pageSize, extra: {'onlyUnread': onlyUnread ? 'true' : null});

  Future<int> unreadCount() async => await client.get('/api/notifications/unread-count') as int;

  Future<void> markNotificationRead(int id) => client.post('/api/notifications/$id/read');

  Future<void> markAllNotificationsRead() => client.post('/api/notifications/read-all');

  // ------------------------------------------------------------------- Vijesti

  Future<PagedResult<NewsItem>> news({int page = 1, int pageSize = 10, String? search}) =>
      _page('/api/news', NewsItem.fromJson, page: page, pageSize: pageSize, search: search);

  String newsImageUrl(int id) => client.uri('/api/news/$id/image').toString();

  Future<void> createNews(String title, String text, String imageName, List<int> imageBytes) =>
      client.sendMultipart(
        'POST',
        '/api/news',
        fields: {'title': title, 'text': text},
        files: [UploadFile(field: 'image', filename: imageName, bytes: imageBytes)],
      );

  Future<void> updateNews(int id, String title, String text, {String? imageName, List<int>? imageBytes}) =>
      client.sendMultipart(
        'PUT',
        '/api/news/$id',
        fields: {'title': title, 'text': text},
        files: [
          if (imageBytes != null) UploadFile(field: 'image', filename: imageName ?? 'slika.png', bytes: imageBytes)
        ],
      );

  Future<void> deleteNews(int id) => client.delete('/api/news/$id');

  // ----------------------------------------------------------------- Izvjestaji

  Map<String, dynamic> _period(DateTime from, DateTime to, [Map<String, dynamic> extra = const {}]) =>
      {'from': _isoDate(from), 'to': _isoDate(to), ...extra};

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [categoryId] je neobavezan: izvještaj samo za jednu kategoriju.
  Future<LoanReport> loanReport(DateTime from, DateTime to, {int? categoryId}) async => LoanReport.fromJson(
      await client.get('/api/reports/loans', query: _period(from, to, {'categoryId': categoryId}))
          as Map<String, dynamic>);

  /// [status] je neobavezan: "Unpaid", "Paid" ili "Cancelled".
  Future<FineReport> fineReport(DateTime from, DateTime to, {String? status}) async => FineReport.fromJson(
      await client.get('/api/reports/fines', query: _period(from, to, {'status': status}))
          as Map<String, dynamic>);

  Future<Uint8List> loanReportPdf(DateTime from, DateTime to, {int? categoryId}) =>
      client.getBytes('/api/reports/loans/pdf', query: _period(from, to, {'categoryId': categoryId}));

  Future<Uint8List> fineReportPdf(DateTime from, DateTime to, {String? status}) =>
      client.getBytes('/api/reports/fines/pdf', query: _period(from, to, {'status': status}));
}
