import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/dialogs.dart';
import '../ui/paged_list_view.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _listKey = GlobalKey<PagedListViewState<Member>>();
  bool? _blocked;
  int? _cityId;
  List<City> _cities = [];

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final page = await context.read<AppState>().api.cities(pageSize: 50);
      if (mounted) setState(() => _cities = page.items);
    } on ApiException {
      // Bez liste gradova filter jednostavno nije dostupan.
    }
  }

  Future<void> _details(Member member) =>
      showDialog<void>(context: context, builder: (_) => _MemberDetailsDialog(member: member));

  Future<void> _block(Member member) async {
    final reason = await askReason(
      context,
      title: 'Blokiranje člana',
      description: '${member.fullName} (${member.membershipNumber}) neće moći rezervisati ni posuđivati knjige.',
      hint: 'Razlog blokiranja',
      minLength: 10,
      confirmText: 'Blokiraj',
    );
    if (reason == null || !mounted) return;

    final api = context.read<AppState>().api;
    final ok = await runAction(context, () => api.blockMember(member.id, reason), success: 'Član je blokiran.');
    if (ok) _listKey.currentState?.reload();
  }

  Future<void> _unblock(Member member) async {
    final yes = await confirm(
      context,
      title: 'Odblokiranje člana',
      message: 'Odblokirati člana ${member.fullName}?',
      confirmText: 'Odblokiraj',
    );
    if (!yes || !mounted) return;

    final api = context.read<AppState>().api;
    final ok = await runAction(context, () => api.unblockMember(member.id), success: 'Član je odblokiran.');
    if (ok) _listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;

    return PagedListView<Member>(
      key: _listKey,
      searchHint: 'Ime, broj karte, korisničko ime ili e-mail',
      leading: [
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<bool?>(
            initialValue: _blocked,
            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('Svi')),
              DropdownMenuItem<bool?>(value: false, child: Text('Aktivni')),
              DropdownMenuItem<bool?>(value: true, child: Text('Blokirani')),
            ],
            onChanged: (v) {
              setState(() => _blocked = v);
              _listKey.currentState?.load(page: 1);
            },
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<int?>(
            key: const ValueKey('member-city'),
            initialValue: _cityId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Grad', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Svi gradovi')),
              for (final c in _cities) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) {
              setState(() => _cityId = v);
              _listKey.currentState?.load(page: 1);
            },
          ),
        ),
      ],
      columns: const ['', 'Član', 'Broj karte', 'E-mail', 'Grad', 'Posudbe', 'Rezerv.', 'Neplaćeno', 'Status', ''],
      fetch: (page, search) => api.members(page: page, search: search, isBlocked: _blocked, cityId: _cityId),
      rowBuilder: (m, reload) => DataRow(cells: [
        DataCell(ApiImage(
          url: m.hasProfileImage ? api.memberImageUrl(m.id) : null,
          width: 36,
          height: 36,
          icon: Icons.person,
        )),
        DataCell(TextButton(onPressed: () => _details(m), child: Text(m.fullName))),
        DataCell(Text(m.membershipNumber)),
        DataCell(Text(m.email)),
        DataCell(Text(m.cityName)),
        DataCell(Text('${m.activeLoans}')),
        DataCell(Text('${m.openReservations}')),
        DataCell(Text(m.unpaidFines > 0 ? '${m.unpaidFines}' : '—',
            style: m.unpaidFines > 0 ? TextStyle(color: Theme.of(context).colorScheme.error) : null)),
        DataCell(m.isBlocked
            ? Tooltip(
                message: m.blockReason ?? '',
                child: Text('Blokiran', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              )
            : const Text('Aktivan')),
        DataCell(m.isBlocked
            ? TextButton(onPressed: () => _unblock(m), child: const Text('Odblokiraj'))
            : TextButton(onPressed: () => _block(m), child: const Text('Blokiraj'))),
      ]),
    );
  }
}


/// Detalji člana: lični podaci i historija (posudbe, rezervacije, zakasnine).
class _MemberDetailsDialog extends StatelessWidget {
  const _MemberDetailsDialog({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;

    return AlertDialog(
      title: DialogTitle('Član: ${member.fullName}'),
      content: SizedBox(
        width: 640,
        height: 460,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 24, runSpacing: 4, children: [
            Text('Broj karte: ${member.membershipNumber}'),
            Text('E-mail: ${member.email}'),
            Text('Telefon: ${member.phoneNumber ?? '—'}'),
            Text('Grad: ${member.cityName}'),
            Text('Član od: ${formatDate(member.createdAt)}'),
            Text(member.isBlocked ? 'Status: blokiran (${member.blockReason ?? ''})' : 'Status: aktivan'),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(children: [
                const TabBar(tabs: [Tab(text: 'Posudbe'), Tab(text: 'Rezervacije'), Tab(text: 'Zakasnine')]),
                Expanded(
                  child: TabBarView(children: [
                    _HistoryList<Loan>(
                      load: () async => (await api.loans(userId: member.id, pageSize: 50)).items,
                      line: (l) => ListTile(
                        dense: true,
                        title: Text(l.bookTitle),
                        subtitle: Text('Posuđeno ${formatDate(l.loanDate)}, rok ${formatDate(l.dueDate)}'
                            '${l.returnDate == null ? '' : ', vraćeno ${formatDate(l.returnDate)}'}'),
                        trailing: Text(Labels.loanStatus(l.status, overdue: l.isOverdue)),
                      ),
                    ),
                    _HistoryList<Reservation>(
                      load: () async => (await api.reservations(userId: member.id, pageSize: 50)).items,
                      line: (r) => ListTile(
                        dense: true,
                        title: Text(r.bookTitle),
                        subtitle: Text('Rezervisano ${formatDate(r.createdAt)}'),
                        trailing: Text(Labels.reservationStatus(r.status)),
                      ),
                    ),
                    _HistoryList<Fine>(
                      load: () async => (await api.fines(userId: member.id, pageSize: 50)).items,
                      line: (f) => ListTile(
                        dense: true,
                        title: Text(f.bookTitle),
                        subtitle: Text('${f.daysLate} d. kašnjenja, ${formatKm(f.amount)}'),
                        trailing: Text(Labels.fineStatus(f.status)),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvori'))],
    );
  }
}

class _HistoryList<T> extends StatefulWidget {
  const _HistoryList({required this.load, required this.line});

  final Future<List<T>> Function() load;
  final Widget Function(T item) line;

  @override
  State<_HistoryList<T>> createState() => _HistoryListState<T>();
}

class _HistoryListState<T> extends State<_HistoryList<T>> {
  late final Future<List<T>> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(child: Text(error is ApiException ? error.message : 'Podaci nisu dostupni.'));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('Nema zapisa.'));
        return ListView(children: [for (final item in items) widget.line(item)]);
      },
    );
  }
}
