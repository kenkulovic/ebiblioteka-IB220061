import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/dialogs.dart';
import '../ui/paged_list_view.dart';
import 'loans_screen.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final _listKey = GlobalKey<PagedListViewState<Reservation>>();
  String? _status;

  LibraryApi get _api => context.read<AppState>().api;

  Future<void> _confirm(Reservation r) async {
    final ok = await runAction(context, () => _api.confirmReservation(r.id),
        success: 'Rezervacija je potvrđena. Član ima 3 dana za preuzimanje.');
    if (ok) _listKey.currentState?.reload();
  }

  Future<void> _cancel(Reservation r) async {
    final reason = await askReason(
      context,
      title: r.status == 'Pending' ? 'Odbijanje zahtjeva' : 'Otkazivanje rezervacije',
      description: '"${r.bookTitle}" – ${r.userFullName}. Član će dobiti notifikaciju s razlogom.',
      hint: 'Razlog (obavezan)',
      minLength: 10,
      confirmText: r.status == 'Pending' ? 'Odbij' : 'Otkaži rezervaciju',
    );
    if (reason == null || !mounted) return;

    final ok = await runAction(context, () => _api.cancelReservation(r.id, reason: reason),
        success: 'Rezervacija je otkazana.');
    if (ok) _listKey.currentState?.reload();
  }

  // "Preuzeto" vodi na formu izdavanja s odabranom rezervacijom.
  Future<void> _pickup(Reservation r) async {
    final issued = await showDialog<bool>(context: context, builder: (_) => IssueLoanDialog(reservationId: r.id));
    if (issued != true || !mounted) return;

    showMessage(context, 'Knjiga "${r.bookTitle}" je izdata, rezervacija je završena.');
    _listKey.currentState?.reload();
  }

  Future<void> _details(Reservation r) async {
    try {
      final details = await _api.reservation(r.id);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => _HistoryDialog(reservation: details));
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PagedListView<Reservation>(
      key: _listKey,
      searchHint: 'Knjiga, član ili broj karte',
      leading: [
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String?>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Svi')),
              for (final s in ['Pending', 'Confirmed', 'Completed', 'Cancelled'])
                DropdownMenuItem<String?>(value: s, child: Text(Labels.reservationStatus(s))),
            ],
            onChanged: (v) {
              setState(() => _status = v);
              _listKey.currentState?.load(page: 1);
            },
          ),
        ),
      ],
      columns: const ['', 'Knjiga', 'Član', 'Zahtjev poslan', 'Preuzimanje do', 'Status', ''],
      fetch: (page, search) => _api.reservations(page: page, search: search, status: _status),
      rowBuilder: (r, reload) => DataRow(cells: [
        DataCell(ApiImage(url: r.bookHasCover ? _api.bookCoverUrl(r.bookId) : null, width: 30, height: 42)),
        DataCell(SizedBox(width: 200, child: Text(r.bookTitle, overflow: TextOverflow.ellipsis))),
        DataCell(Text('${r.userFullName}\n${r.membershipNumber}', style: Theme.of(context).textTheme.bodySmall)),
        DataCell(Text(formatDateTime(r.createdAt))),
        DataCell(Text(formatDate(r.pickupDeadline))),
        DataCell(Text(
          Labels.reservationStatus(r.status),
          style: r.status == 'Cancelled' ? TextStyle(color: scheme.outline) : null,
        )),
        DataCell(Row(children: [
          if (r.status == 'Pending')
            TextButton(onPressed: () => _confirm(r), child: const Text('Potvrdi')),
          if (r.status == 'Confirmed')
            TextButton(onPressed: () => _pickup(r), child: const Text('Preuzeto')),
          if (r.isOpen)
            TextButton(
              onPressed: () => _cancel(r),
              child: Text(r.status == 'Pending' ? 'Odbij' : 'Otkaži'),
            ),
          IconButton(tooltip: 'Historija promjena', onPressed: () => _details(r), icon: const Icon(Icons.history)),
        ])),
      ]),
    );
  }
}

/// Audit trag: ko je, kada i zašto mijenjao status rezervacije.
class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: DialogTitle('Historija: ${reservation.bookTitle}'),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Član: ${reservation.userFullName} (${reservation.membershipNumber})'),
          const SizedBox(height: 12),
          for (final h in reservation.history)
            ListTile(
              dense: true,
              leading: const Icon(Icons.circle, size: 12),
              title: Text(h.fromStatus == null
                  ? 'Kreirano: ${Labels.reservationStatus(h.toStatus)}'
                  : '${Labels.reservationStatus(h.fromStatus!)} → ${Labels.reservationStatus(h.toStatus)}'),
              subtitle: Text(
                '${formatDateTime(h.changedAt)} · ${h.changedBy}${h.reason == null ? '' : '\nRazlog: ${h.reason}'}',
              ),
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvori'))],
    );
  }
}
