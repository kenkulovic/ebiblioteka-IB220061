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
      ],
      columns: const ['', 'Član', 'Broj karte', 'E-mail', 'Grad', 'Posudbe', 'Rezerv.', 'Neplaćeno', 'Status', ''],
      fetch: (page, search) => api.members(page: page, search: search, isBlocked: _blocked),
      rowBuilder: (m, reload) => DataRow(cells: [
        DataCell(ApiImage(
          url: m.hasProfileImage ? api.memberImageUrl(m.id) : null,
          width: 36,
          height: 36,
          icon: Icons.person,
        )),
        DataCell(Text(m.fullName)),
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
