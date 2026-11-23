/// Tekstovi za prikaz i formatiranje (bosanski). Dijele ih obje aplikacije.
class Labels {
  static String reservationStatus(String status) => switch (status) {
        'Pending' => 'Na čekanju',
        'Confirmed' => 'Potvrđena',
        'Completed' => 'Završena',
        'Cancelled' => 'Otkazana',
        _ => status,
      };

  static String loanStatus(String status, {bool overdue = false}) {
    if (status == 'Active') {
      return overdue ? 'Kasni' : 'Aktivna';
    }
    return status == 'Returned' ? 'Vraćena' : status;
  }

  static String fineStatus(String status) => switch (status) {
        'Unpaid' => 'Neplaćena',
        'Paid' => 'Plaćena',
        'Cancelled' => 'Stornirana',
        _ => status,
      };

  static String paymentStatus(String status) => switch (status) {
        'Pending' => 'Na čekanju',
        'Completed' => 'Završena',
        'Failed' => 'Neuspjela',
        'Refunded' => 'Vraćena',
        _ => status,
      };

  static String paymentMethod(String? method) => switch (method) {
        'PayPal' => 'PayPal',
        'Counter' => 'Šalter',
        _ => '—',
      };
}

String _two(int value) => value.toString().padLeft(2, '0');

String formatDate(DateTime? value) =>
    value == null ? '—' : '${_two(value.day)}.${_two(value.month)}.${value.year}.';

String formatDateTime(DateTime? value) =>
    value == null ? '—' : '${formatDate(value)} ${_two(value.hour)}:${_two(value.minute)}';

/// Iznos u konvertibilnim markama s decimalnim zarezom, npr. "8,50 KM".
String formatKm(num amount) => '${amount.toStringAsFixed(2).replaceAll('.', ',')} KM';

String formatEur(num amount) => '${amount.toStringAsFixed(2).replaceAll('.', ',')} EUR';
