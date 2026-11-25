/// Pravila unosa koja dijele registracija, profil i reset lozinke. Poruke navode format i ograničenja.
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _phonePattern = RegExp(r'^\+?[0-9 /-]{6,20}$');
final _userNamePattern = RegExp(r'^[a-zA-Z0-9\-._@+]{3,50}$');
final _codePattern = RegExp(r'^\d{6}$');

String? validateName(String? value, String field) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Unesite $field.';
  return text.length > 50 ? 'Najviše 50 znakova.' : null;
}

String? validateUserName(String? value) => _userNamePattern.hasMatch(value?.trim() ?? '')
    ? null
    : 'Korisničko ime: 3 do 50 znakova (slova bez kvačica a-z, cifre i - . _ @ +).';

String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  return text.length <= 100 && _emailPattern.hasMatch(text)
      ? null
      : 'Unesite e-mail adresu u formatu ime@domena.ba.';
}

/// Telefon nije obavezan.
String? validatePhone(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty || _phonePattern.hasMatch(text)
      ? null
      : 'Telefon: 6 do 20 znakova (cifre, razmak, / ili -), npr. +387 61 123 456.';
}

String? validateNewPassword(String? value) {
  final length = value?.length ?? 0;
  return length >= 4 && length <= 100 ? null : 'Lozinka mora imati 4 do 100 znakova.';
}

String? validateRepeatedPassword(String? value, String password) =>
    value != password ? 'Lozinke se ne poklapaju.' : null;

String? validateResetCode(String? value) =>
    _codePattern.hasMatch(value?.trim() ?? '') ? null : 'Unesite kod od 6 cifara iz e-maila.';
