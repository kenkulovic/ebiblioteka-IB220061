import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'authors_screen.dart';
import 'books_screen.dart';
import 'fines_screen.dart';
import 'loans_screen.dart';
import 'lookups_screen.dart';
import 'members_screen.dart';
import 'news_screen.dart';
import 'reports_screen.dart';
import 'reservations_screen.dart';

class _Section {
  const _Section(this.title, this.icon, this.builder);

  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

/// Okvir aplikacije: bočni meni i sadržaj odabranog dijela.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static final _sections = [
    _Section('Knjige', Icons.menu_book, (_) => const BooksScreen()),
    _Section('Autori', Icons.edit_note, (_) => const AuthorsScreen()),
    _Section('Članovi', Icons.people, (_) => const MembersScreen()),
    _Section('Posudbe', Icons.swap_horiz, (_) => const LoansScreen()),
    _Section('Rezervacije', Icons.bookmark, (_) => const ReservationsScreen()),
    _Section('Zakasnine', Icons.payments, (_) => const FinesScreen()),
    _Section('Izvještaji', Icons.assessment, (_) => const ReportsScreen()),
    _Section('Vijesti', Icons.newspaper, (_) => const NewsScreen()),
    _Section('Šifarnici', Icons.category, (_) => const LookupsScreen()),
  ];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final section = _sections[_index];

    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: _index,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (i) => setState(() => _index = i),
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Icon(Icons.local_library, size: 32, color: Theme.of(context).colorScheme.primary),
          ),
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Tooltip(
                    message: state.user?.fullName ?? '',
                    child: const Icon(Icons.account_circle, size: 28),
                  ),
                  const SizedBox(height: 4),
                  TextButton(onPressed: state.logout, child: const Text('Odjava')),
                ]),
              ),
            ),
          ),
          destinations: [
            for (final s in _sections)
              NavigationRailDestination(icon: Icon(s.icon), label: Text(s.title)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(section.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              // Key: pri promjeni dijela stanje prethodnog ekrana se odbacuje.
              Expanded(child: KeyedSubtree(key: ValueKey(_index), child: section.builder(context))),
            ]),
          ),
        ),
      ]),
    );
  }
}
