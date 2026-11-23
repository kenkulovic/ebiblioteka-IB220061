import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';

/// Stanje prijave. Desktop aplikacija je samo za bibliotekare (ulogu Administrator).
class AppState extends ChangeNotifier {
  AppState(this.api) {
    // Ako server odbije token (istekao), korisnik se vraca na prijavu.
    api.client.onUnauthorized = logout;
  }

  final LibraryApi api;

  LoginResult? user;

  Future<void> login(String userName, String password) async {
    final result = await api.login(userName, password);

    if (!result.isAdministrator) {
      api.client.token = null;
      throw ApiException('Ova aplikacija je namijenjena bibliotekarima. Članovi koriste mobilnu aplikaciju.');
    }

    user = result;
    notifyListeners();
  }

  void logout() {
    api.client.token = null;
    if (user != null) {
      user = null;
      notifyListeners();
    }
  }
}
