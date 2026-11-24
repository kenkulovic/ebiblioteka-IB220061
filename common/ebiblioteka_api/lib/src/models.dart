// Modeli odgovora API-ja. Nazivi polja odgovaraju JSON-u koji server vraca (camelCase).

DateTime _date(Object? value) => DateTime.parse(value as String).toLocal();

DateTime? _dateOrNull(Object? value) => value == null ? null : _date(value);

double? _doubleOrNull(Object? value) => (value as num?)?.toDouble();

double _double(Object? value) => (value as num).toDouble();

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    (value as List<dynamic>? ?? const []).map((e) => parse(e as Map<String, dynamic>)).toList();

class PagedResult<T> {
  PagedResult({required this.items, required this.totalCount, required this.page, required this.pageSize});

  factory PagedResult.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) =>
      PagedResult(
        items: _list(json['items'], parse),
        totalCount: json['totalCount'] as int,
        page: json['page'] as int,
        pageSize: json['pageSize'] as int,
      );

  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  int get totalPages => totalCount == 0 ? 1 : (totalCount + pageSize - 1) ~/ pageSize;
}

class LoginResult {
  LoginResult.fromJson(Map<String, dynamic> json)
      : token = json['token'] as String,
        userId = json['userId'] as int,
        userName = json['userName'] as String,
        firstName = json['firstName'] as String,
        lastName = json['lastName'] as String,
        roles = (json['roles'] as List<dynamic>).cast<String>();

  final String token;
  final int userId;
  final String userName;
  final String firstName;
  final String lastName;
  final List<String> roles;

  String get fullName => '$firstName $lastName';

  bool get isAdministrator => roles.contains('Administrator');

  bool get isMember => roles.contains('Member');
}

class Lookup {
  Lookup.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String;

  final int id;
  final String name;
}

class City {
  City.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String,
        countryId = json['countryId'] as int,
        countryName = json['countryName'] as String;

  final int id;
  final String name;
  final int countryId;
  final String countryName;
}

class Publisher {
  Publisher.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String,
        cityId = json['cityId'] as int,
        cityName = json['cityName'] as String;

  final int id;
  final String name;
  final int cityId;
  final String cityName;
}

class Author {
  Author.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        firstName = json['firstName'] as String,
        lastName = json['lastName'] as String,
        biography = json['biography'] as String?,
        countryId = json['countryId'] as int,
        countryName = json['countryName'] as String,
        bookCount = json['bookCount'] as int;

  final int id;
  final String firstName;
  final String lastName;
  final String? biography;
  final int countryId;
  final String countryName;
  final int bookCount;

  String get fullName => '$firstName $lastName';
}

class BookItem {
  BookItem.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        title = json['title'] as String,
        publishedYear = json['publishedYear'] as int?,
        categoryId = json['categoryId'] as int,
        categoryName = json['categoryName'] as String,
        authors = (json['authors'] as List<dynamic>).cast<String>(),
        totalCopies = json['totalCopies'] as int,
        availableCopies = json['availableCopies'] as int,
        averageRating = _doubleOrNull(json['averageRating']),
        hasCover = json['hasCover'] as bool;

  final int id;
  final String title;
  final int? publishedYear;
  final int categoryId;
  final String categoryName;
  final List<String> authors;
  final int totalCopies;
  final int availableCopies;
  final double? averageRating;
  final bool hasCover;

  String get authorsText => authors.join(', ');
}

class BookAuthor {
  BookAuthor.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        fullName = json['fullName'] as String;

  final int id;
  final String fullName;
}

class BookDetails {
  BookDetails.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        title = json['title'] as String,
        publishedYear = json['publishedYear'] as int?,
        pageCount = json['pageCount'] as int?,
        description = json['description'] as String?,
        totalCopies = json['totalCopies'] as int,
        availableCopies = json['availableCopies'] as int,
        categoryId = json['categoryId'] as int,
        categoryName = json['categoryName'] as String,
        publisherId = json['publisherId'] as int?,
        publisherName = json['publisherName'] as String?,
        authors = _list(json['authors'], BookAuthor.fromJson),
        averageRating = _doubleOrNull(json['averageRating']),
        reviewCount = json['reviewCount'] as int,
        hasCover = json['hasCover'] as bool;

  final int id;
  final String title;
  final int? publishedYear;
  final int? pageCount;
  final String? description;
  final int totalCopies;
  final int availableCopies;
  final int categoryId;
  final String categoryName;
  final int? publisherId;
  final String? publisherName;
  final List<BookAuthor> authors;
  final double? averageRating;
  final int reviewCount;
  final bool hasCover;

  String get authorsText => authors.map((a) => a.fullName).join(', ');
}

class Member {
  Member.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        userName = json['userName'] as String,
        firstName = json['firstName'] as String,
        lastName = json['lastName'] as String,
        email = json['email'] as String,
        phoneNumber = json['phoneNumber'] as String?,
        membershipNumber = json['membershipNumber'] as String,
        cityId = json['cityId'] as int,
        cityName = json['cityName'] as String,
        isBlocked = json['isBlocked'] as bool,
        blockReason = json['blockReason'] as String?,
        createdAt = _date(json['createdAt']),
        hasProfileImage = json['hasProfileImage'] as bool,
        activeLoans = json['activeLoans'] as int,
        openReservations = json['openReservations'] as int,
        unpaidFines = json['unpaidFines'] as int;

  final int id;
  final String userName;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String membershipNumber;
  final int cityId;
  final String cityName;
  final bool isBlocked;
  final String? blockReason;
  final DateTime createdAt;
  final bool hasProfileImage;
  final int activeLoans;
  final int openReservations;
  final int unpaidFines;

  String get fullName => '$firstName $lastName';
}

class Loan {
  Loan.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        loanDate = _date(json['loanDate']),
        dueDate = _date(json['dueDate']),
        returnDate = _dateOrNull(json['returnDate']),
        extensionCount = json['extensionCount'] as int,
        status = json['status'] as String,
        isOverdue = json['isOverdue'] as bool,
        daysOverdue = json['daysOverdue'] as int,
        userId = json['userId'] as int,
        userFullName = json['userFullName'] as String,
        membershipNumber = json['membershipNumber'] as String,
        bookId = json['bookId'] as int,
        bookTitle = json['bookTitle'] as String,
        bookHasCover = json['bookHasCover'] as bool,
        fineId = json['fineId'] as int?,
        hasReview = json['hasReview'] as bool;

  final int id;
  final DateTime loanDate;
  final DateTime dueDate;
  final DateTime? returnDate;
  final int extensionCount;
  final String status;
  final bool isOverdue;
  final int daysOverdue;
  final int userId;
  final String userFullName;
  final String membershipNumber;
  final int bookId;
  final String bookTitle;
  final bool bookHasCover;
  final int? fineId;
  final bool hasReview;

  bool get isActive => status == 'Active';
}

class Reservation {
  Reservation.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        status = json['status'] as String,
        createdAt = _date(json['createdAt']),
        pickupDeadline = _dateOrNull(json['pickupDeadline']),
        userId = json['userId'] as int,
        userFullName = json['userFullName'] as String,
        membershipNumber = json['membershipNumber'] as String,
        bookId = json['bookId'] as int,
        bookTitle = json['bookTitle'] as String,
        bookHasCover = json['bookHasCover'] as bool,
        history = _list(json['history'], ReservationHistory.fromJson);

  final int id;
  final String status;
  final DateTime createdAt;
  final DateTime? pickupDeadline;
  final int userId;
  final String userFullName;
  final String membershipNumber;
  final int bookId;
  final String bookTitle;
  final bool bookHasCover;

  /// Popunjeno samo kad se dohvate detalji rezervacije.
  final List<ReservationHistory> history;

  bool get isOpen => status == 'Pending' || status == 'Confirmed';
}

class ReservationHistory {
  ReservationHistory.fromJson(Map<String, dynamic> json)
      : fromStatus = json['fromStatus'] as String?,
        toStatus = json['toStatus'] as String,
        changedAt = _date(json['changedAt']),
        reason = json['reason'] as String?,
        changedBy = json['changedBy'] as String;

  final String? fromStatus;
  final String toStatus;
  final DateTime changedAt;
  final String? reason;
  final String changedBy;
}

class Fine {
  Fine.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        amount = _double(json['amount']),
        daysLate = json['daysLate'] as int,
        status = json['status'] as String,
        isPaid = json['isPaid'] as bool,
        createdAt = _date(json['createdAt']),
        paidAt = _dateOrNull(json['paidAt']),
        loanId = json['loanId'] as int,
        bookId = json['bookId'] as int,
        bookTitle = json['bookTitle'] as String,
        bookHasCover = json['bookHasCover'] as bool,
        userId = json['userId'] as int,
        userFullName = json['userFullName'] as String,
        paymentMethod = json['paymentMethod'] as String?,
        hasPendingPayment = json['hasPendingPayment'] as bool,
        pendingPaymentId = json['pendingPaymentId'] as int?;

  final int id;
  final double amount;
  final int daysLate;
  final String status;
  final bool isPaid;
  final DateTime createdAt;
  final DateTime? paidAt;
  final int loanId;
  final int bookId;
  final String bookTitle;
  final bool bookHasCover;
  final int userId;
  final String userFullName;
  final String? paymentMethod;
  final bool hasPendingPayment;

  /// Uplata koja je pokrenuta, ali nije zavrsena; clan je moze otkazati.
  final int? pendingPaymentId;

  bool get isUnpaid => status == 'Unpaid';
}

class Payment {
  Payment.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        fineId = json['fineId'] as int,
        method = json['method'] as String,
        status = json['status'] as String,
        amountKm = _double(json['amountKm']),
        amountEur = _doubleOrNull(json['amountEur']),
        exchangeRate = _doubleOrNull(json['exchangeRate']),
        payPalOrderId = json['payPalOrderId'] as String?,
        payPalCaptureId = json['payPalCaptureId'] as String?,
        createdAt = _date(json['createdAt']),
        completedAt = _dateOrNull(json['completedAt']),
        refundedAt = _dateOrNull(json['refundedAt']),
        refundedAmountEur = _doubleOrNull(json['refundedAmountEur']),
        refundReason = json['refundReason'] as String?,
        refundedBy = json['refundedBy'] as String?;

  final int id;
  final int fineId;
  final String method;
  final String status;
  final double amountKm;
  final double? amountEur;
  final double? exchangeRate;
  final String? payPalOrderId;
  final String? payPalCaptureId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? refundedAt;
  final double? refundedAmountEur;
  final String? refundReason;
  final String? refundedBy;

  bool get isPayPal => method == 'PayPal';

  /// Povrat je moguc samo za zavrsene PayPal uplate.
  bool get canRefund => isPayPal && status == 'Completed';
}

class PaymentInit {
  PaymentInit.fromJson(Map<String, dynamic> json)
      : paymentId = json['paymentId'] as int,
        payPalOrderId = json['payPalOrderId'] as String,
        approvalUrl = json['approvalUrl'] as String,
        returnUrl = json['returnUrl'] as String,
        cancelUrl = json['cancelUrl'] as String,
        amountKm = _double(json['amountKm']),
        amountEur = _double(json['amountEur']),
        exchangeRate = _double(json['exchangeRate']);

  final int paymentId;
  final String payPalOrderId;
  final String approvalUrl;
  final String returnUrl;
  final String cancelUrl;
  final double amountKm;
  final double amountEur;
  final double exchangeRate;
}

class NewsItem {
  NewsItem.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        title = json['title'] as String,
        text = json['text'] as String,
        publishedAt = _date(json['publishedAt']);

  final int id;
  final String title;
  final String text;
  final DateTime publishedAt;
}

class AppNotification {
  AppNotification.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        title = json['title'] as String,
        text = json['text'] as String,
        isRead = json['isRead'] as bool,
        createdAt = _date(json['createdAt']);

  final int id;
  final String title;
  final String text;
  final bool isRead;
  final DateTime createdAt;
}

class Review {
  Review.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        rating = json['rating'] as int,
        comment = json['comment'] as String?,
        createdAt = _date(json['createdAt']),
        updatedAt = _dateOrNull(json['updatedAt']),
        loanId = json['loanId'] as int,
        userId = json['userId'] as int,
        userFullName = json['userFullName'] as String,
        bookId = json['bookId'] as int,
        bookTitle = json['bookTitle'] as String;

  final int id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int loanId;
  final int userId;
  final String userFullName;
  final int bookId;
  final String bookTitle;
}

class RecommendationReason {
  RecommendationReason.fromJson(Map<String, dynamic> json)
      : bookId = json['bookId'] as int,
        bookTitle = json['bookTitle'] as String,
        similarity = _double(json['similarity']),
        commonUsers = json['commonUsers'] as int,
        userRating = json['userRating'] as int;

  final int bookId;
  final String bookTitle;
  final double similarity;
  final int commonUsers;

  /// Ocjena koju je clan dao toj knjizi.
  final int userRating;
}

class Recommendation {
  Recommendation.fromJson(Map<String, dynamic> json)
      : book = BookItem.fromJson(json['book'] as Map<String, dynamic>),
        score = _double(json['score']),
        source = json['source'] as String,
        explanation = json['explanation'] as String,
        reasons = _list(json['reasons'], RecommendationReason.fromJson);

  final BookItem book;
  final double score;
  final String source;
  final String explanation;
  final List<RecommendationReason> reasons;
}

class SimilarBook {
  SimilarBook.fromJson(Map<String, dynamic> json)
      : book = BookItem.fromJson(json['book'] as Map<String, dynamic>),
        similarity = _double(json['similarity']),
        commonUsers = json['commonUsers'] as int;

  final BookItem book;
  final double similarity;
  final int commonUsers;
}

class CountItem {
  CountItem.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        count = json['count'] as int;

  final String name;
  final int count;
}

class TopBook {
  TopBook.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        count = json['count'] as int,
        averageRating = _doubleOrNull(json['averageRating']);

  final String name;
  final int count;
  final double? averageRating;
}

class FineMember {
  FineMember.fromJson(Map<String, dynamic> json)
      : member = json['member'] as String,
        count = json['count'] as int,
        totalKm = _double(json['totalKm']),
        unpaidKm = _double(json['unpaidKm']);

  final String member;
  final int count;
  final double totalKm;
  final double unpaidKm;
}

class LoanReport {
  LoanReport.fromJson(Map<String, dynamic> json)
      : categoryName = json['categoryName'] as String?,
        totalLoans = json['totalLoans'] as int,
        returned = json['returned'] as int,
        active = json['active'] as int,
        overdueNow = json['overdueNow'] as int,
        averageLoanDays = _doubleOrNull(json['averageLoanDays']),
        topBooks = _list(json['topBooks'], TopBook.fromJson),
        byCategory = _list(json['byCategory'], CountItem.fromJson);

  final String? categoryName;
  final int totalLoans;
  final int returned;
  final int active;
  final int overdueNow;
  final double? averageLoanDays;
  final List<TopBook> topBooks;
  final List<CountItem> byCategory;
}

class FineStatusTotal {
  FineStatusTotal.fromJson(Map<String, dynamic> json)
      : count = json['count'] as int,
        amountKm = _double(json['amountKm']);

  final int count;
  final double amountKm;
}

class FineReport {
  FineReport.fromJson(Map<String, dynamic> json)
      : averageDaysLate = _doubleOrNull(json['averageDaysLate']),
        members = _list(json['members'], FineMember.fromJson),
        totalFines = json['totalFines'] as int,
        totalAmountKm = _double(json['totalAmountKm']),
        unpaid = FineStatusTotal.fromJson(json['unpaid'] as Map<String, dynamic>),
        paid = FineStatusTotal.fromJson(json['paid'] as Map<String, dynamic>),
        cancelled = FineStatusTotal.fromJson(json['cancelled'] as Map<String, dynamic>),
        paidPayPalKm = _double(json['paidPayPalKm']),
        paidCounterKm = _double(json['paidCounterKm']),
        refundedCount = json['refundedCount'] as int,
        refundedEur = _double(json['refundedEur']);

  final double? averageDaysLate;
  final List<FineMember> members;
  final int totalFines;
  final double totalAmountKm;
  final FineStatusTotal unpaid;
  final FineStatusTotal paid;
  final FineStatusTotal cancelled;
  final double paidPayPalKm;
  final double paidCounterKm;
  final int refundedCount;
  final double refundedEur;
}
