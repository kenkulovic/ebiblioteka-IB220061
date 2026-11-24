import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';

/// Adresa API-ja se zadaje pri pokretanju: --dart-define=API_BASE_URL=http://10.0.2.2:5028
/// (10.0.2.2 je adresa računara iz Android emulatora).
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

void main() {
  runApp(const EBibliotekaApp());
}

class EBibliotekaApp extends StatelessWidget {
  const EBibliotekaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F4E8C)),
    );

    if (apiBaseUrl.isEmpty) {
      return MaterialApp(title: 'eBiblioteka', theme: theme, home: const _MissingConfigScreen());
    }

    return ChangeNotifierProvider(
      create: (_) => AppState(LibraryApi(ApiClient(baseUrl: apiBaseUrl))),
      child: MaterialApp(
        title: 'eBiblioteka',
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: const Locale('bs'),
        supportedLocales: const [Locale('bs'), Locale('hr'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Consumer<AppState>(
          builder: (context, state, _) => state.user == null ? const LoginScreen() : const MainShell(),
        ),
      ),
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SelectableText(
            'Adresa API-ja nije zadana.\n\n'
            'Pokrenite aplikaciju s:\n'
            'flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5028',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
