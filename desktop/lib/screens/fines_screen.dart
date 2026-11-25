import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/dialogs.dart';
import '../ui/paged_list_view.dart';

class FinesScreen extends StatefulWidget {
  const FinesScreen({super.key});

  @override
  State<FinesScreen> createState() => _FinesScreenState();
}

class _FinesScreenState extends State<FinesScreen> {
  final _listKey = GlobalKey<PagedListViewState<Fine>>();
  String? _status;

  LibraryApi get _api => context.read<AppState>().api;

  Future<void> _payAtCounter(Fine fine) async {
    final ok = await confirm(
      context,
      title: 'Označi plaćeno',
      message: 'Evidentirati uplatu zakasnine ${formatKm(fine.amount)} (${fine.userFullName}) na šalteru?',
      confirmText: 'Označi plaćeno',
    );
    if (!ok || !mounted) return;

    final done = await runAction(context, () => _api.payFineAtCounter(fine.id), success: 'Uplata je evidentirana.');
    if (done) _listKey.currentState?.reload();
  }

  Future<void> _refundFromRow(Fine fine) async {
    List<Payment> payments;
    try {
      payments = await _api.finePayments(fine.id);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      return;
    }
    final payment = payments.where((p) => p.canRefund).firstOrNull;
    if (!mounted) return;
    if (payment == null) {
      showMessage(context, 'Za ovu zakasninu nema PayPal uplate koja se može vratiti.', error: true);
      return;
    }
    if (await _refundPayment(context, _api, fine, payment)) _listKey.currentState?.reload();
  }

  Future<void> _payments(Fine fine) async {
    await showDialog<void>(context: context, builder: (_) => _PaymentsDialog(fine: fine));
    _listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PagedListView<Fine>(
      key: _listKey,
      searchHint: 'Knjiga, član ili broj karte',
      leading: [
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String?>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Sve')),
              for (final s in ['Unpaid', 'Paid', 'Cancelled'])
                DropdownMenuItem<String?>(value: s, child: Text(Labels.fineStatus(s))),
            ],
            onChanged: (v) {
              setState(() => _status = v);
              _listKey.currentState?.load(page: 1);
            },
          ),
        ),
      ],
      columns: const ['', 'Knjiga', 'Član', 'Dana', 'Iznos', 'Status', 'Način', ''],
      fetch: (page, search) => _api.fines(page: page, search: search, status: _status),
      rowBuilder: (f, reload) => DataRow(cells: [
        DataCell(ApiImage(url: f.bookHasCover ? _api.bookCoverUrl(f.bookId) : null, width: 30, height: 42)),
        DataCell(SizedBox(width: 200, child: Text(f.bookTitle, overflow: TextOverflow.ellipsis))),
        DataCell(Text(f.userFullName)),
        DataCell(Text('${f.daysLate}')),
        DataCell(Text(formatKm(f.amount))),
        DataCell(Text(
          Labels.fineStatus(f.status),
          style: TextStyle(
            color: f.isUnpaid ? scheme.error : (f.isPaid ? Colors.green.shade700 : scheme.outline),
            fontWeight: FontWeight.w600,
          ),
        )),
        DataCell(Text(Labels.paymentMethod(f.paymentMethod))),
        DataCell(Row(children: [
          if (f.isUnpaid && !f.hasPendingPayment)
            TextButton(onPressed: () => _payAtCounter(f), child: const Text('Označi plaćeno')),
          if (f.isUnpaid && f.hasPendingPayment) const Text('Online plaćanje u toku'),
          if (f.isPaid && f.paymentMethod == 'PayPal')
            TextButton(
              key: ValueKey('fine-refund-${f.id}'),
              onPressed: () => _refundFromRow(f),
              child: const Text('Vrati uplatu'),
            ),
          if (f.isPaid && f.paymentMethod == 'Counter')
            const Tooltip(
              message: _counterRefundReason,
              child: TextButton(onPressed: null, child: Text('Vrati uplatu')),
            ),
          TextButton(onPressed: () => _payments(f), child: const Text('Uplate')),
        ])),
      ]),
    );
  }
}

const _counterRefundReason = 'Uplata na šalteru ne vraća se kroz sistem; povrat je moguć samo za PayPal uplate.';

/// Povrat PayPal uplate: panel sa stvarno naplaćenim iznosom i razlogom, zatim potvrda. Vraća true ako je uspio.
Future<bool> _refundPayment(BuildContext context, LibraryApi api, Fine fine, Payment payment) async {
  final amount = '${formatEur(payment.amountEur ?? 0)} (${formatKm(payment.amountKm)})';
  final reason = await askReason(
    context,
    title: 'Povrat uplate',
    description: 'Zakasnina: ${fine.bookTitle} – ${fine.userFullName} (${fine.daysLate} d.), '
        'plaćeno ${formatDate(fine.paidAt)} putem PayPal-a.\n\n'
        'Iznos za povrat (stvarno naplaćen): $amount. Zakasnina postaje stornirana, '
        'a član će dobiti notifikaciju i e-mail.',
    hint: 'Razlog povrata (obavezan)',
    minLength: 10,
    confirmText: 'Vrati uplatu',
  );
  if (reason == null || !context.mounted) return false;

  final yes = await confirm(
    context,
    title: 'Potvrda povrata',
    message: 'Vratiti $amount članu ${fine.userFullName}? Povrat se ne može poništiti.',
    confirmText: 'Potvrdi povrat',
  );
  if (!yes || !context.mounted) return false;

  return runAction(context, () => api.refundPayment(payment.id, reason), success: 'Uplata je vraćena.');
}

/// Uplate jedne zakasnine; PayPal uplata se može vratiti uz razlog.
class _PaymentsDialog extends StatefulWidget {
  const _PaymentsDialog({required this.fine});

  final Fine fine;

  @override
  State<_PaymentsDialog> createState() => _PaymentsDialogState();
}

class _PaymentsDialogState extends State<_PaymentsDialog> {
  List<Payment>? _payments;
  String? _error;

  LibraryApi get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final payments = await _api.finePayments(widget.fine.id);
      if (mounted) setState(() => _payments = payments);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _refund(Payment payment) async {
    if (await _refundPayment(context, _api, widget.fine, payment)) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final fine = widget.fine;

    return AlertDialog(
      title: DialogTitle('Uplate: ${fine.bookTitle}'),
      content: SizedBox(
        width: 620,
        child: _error != null
            ? Text(_error!)
            : _payments == null
                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                : _payments!.isEmpty
                    ? const Text('Za ovu zakasninu nema uplata.')
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final p in _payments!)
                          Card(
                            child: ListTile(
                              title: Text('${Labels.paymentMethod(p.method)} · ${Labels.paymentStatus(p.status)}'),
                              subtitle: Text(_describe(p)),
                              trailing: p.canRefund
                                  ? FilledButton.tonal(onPressed: () => _refund(p), child: const Text('Vrati uplatu'))
                                  : (p.method == 'Counter' && p.status == 'Completed'
                                      ? const Tooltip(
                                          message: _counterRefundReason,
                                          child: FilledButton.tonal(onPressed: null, child: Text('Vrati uplatu')),
                                        )
                                      : null),
                            ),
                          ),
                      ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvori'))],
    );
  }

  String _describe(Payment p) {
    final lines = <String>[
      '${formatDateTime(p.createdAt)} · ${formatKm(p.amountKm)}'
          '${p.amountEur == null ? '' : ' (${formatEur(p.amountEur!)}, kurs ${p.exchangeRate.toString().replaceAll('.', ',')})'}',
    ];
    if (p.refundedAt != null) {
      lines.add('Vraćeno ${formatDateTime(p.refundedAt)}: ${formatEur(p.refundedAmountEur ?? 0)}'
          ' (${p.refundedBy ?? '—'}). Razlog: ${p.refundReason ?? '—'}');
    }
    return lines.join('\n');
  }
}
