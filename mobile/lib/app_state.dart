import 'dart:async';

import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';

/// Stanje prijave i broj nepročitanih obavijesti (osvježava se periodično, bez ručnog osvježavanja).
class AppState extends ChangeNotifier {
  AppState(this.api) {
    // Ako server odbije token (istekao), korisnik se vraća na prijavu.
    api.client.onUnauthorized = logout;
  }

  static const _pollInterval = Duration(seconds: 20);

  final LibraryApi api;

  LoginResult? user;
  int unreadCount = 0;

  Timer? _poller;

  Future<void> login(String userName, String password) async {
    _accept(await api.login(userName, password));
  }

  Future<void> register({
    required String userName,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required int cityId,
  }) async {
    _accept(await api.register(
      userName: userName,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      cityId: cityId,
    ));
  }

  void _accept(LoginResult result) {
    if (!result.isMember) {
      api.client.token = null;
      throw ApiException('Ova aplikacija je namijenjena članovima biblioteke.');
    }

    user = result;
    notifyListeners();
    refreshUnread();
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) => refreshUnread());
  }

  Future<void> refreshUnread() async {
    if (user == null) return;

    try {
      final count = await api.unreadCount();
      if (count != unreadCount) {
        unreadCount = count;
        notifyListeners();
      }
    } on ApiException {
      // Privremeni problem s mrežom: broj se osvježava pri sljedećem pokušaju.
    }
  }

  void logout() {
    _poller?.cancel();
    _poller = null;
    api.client.token = null;
    unreadCount = 0;
    if (user != null) {
      user = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }
}
