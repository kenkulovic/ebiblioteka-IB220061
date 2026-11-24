import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/async_list.dart';
import '../ui/dialogs.dart';
import 'paypal_screen.dart';

/// Moje knjige: posudbe (produženje, ocjenjivanje), rezervacije i zakasnine (plaćanje).
class MyLibraryScreen extends StatelessWidget {
  const MyLibraryScreen({super.key, this.initialTab = 0});

  /// 0 = posudbe, 1 = rezervacije, 2 = zakasnine.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moje knjige'),
          bottom: const TabBar(tabs: [Tab(text: 'Posudbe'), Tab(text: 'Rezervacije'), Tab(text: 'Zakasnine')]),
        ),
        body: const TabBarView(children: [_LoansTab(), _ReservationsTab(), _FinesTab()]),
      ),
    );
  }
}

class _LoansTab extends StatelessWidget {
  const _LoansTab();

  Future<void> _extend(BuildContext context, Loan loan, Future<void> Function() reload) async {
    final ok = await confirm(
      context,
      title: 'Produženje posudbe',
      message: 'Produžiti posudbu knjige "${loan.bookTitle}" za 7 dana? Moguće je samo jedno produženje.',
      confirmText: 'Produži',
    );
    if (!ok || !context.mounted) return;

    final api = context.read<AppState>().api;
    if (await runAction(context, () => api.extendLoan(loan.id), success: 'Posudba je produžena.')) {
      await reload();
    }
  }

  Future<void> _rate(BuildContext context, Loan loan, Future<void> Function() reload) async {
    final result = await showDialog<(int, String?)>(context: context, builder: (_) => _RatingDialog(title: loan.bookTitle));
    if (result == null || !context.mounted) return;

    final api = context.read<AppState>().api;
    if (await runAction(context, () => api.createReview(loan.id, result.$1, result.$2), success: 'Hvala na ocjeni!')) {
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final scheme = Theme.of(context).colorScheme;

    return AsyncList<Loan>(
      emptyText: 'Nemate posudbi.',
      load: () async => (await api.myLoans(pageSize: 50)).items,
      itemBuilder: (context, loan, reload) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ApiImage(url: loan.bookHasCover ? api.bookCoverUrl(loan.bookId) : null, width: 52, height: 74),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(loan.bookTitle, style: Theme.of(context).textTheme.titleSmall),
                Text('Posuđeno: ${formatDate(loan.loanDate)}', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  loan.isActive ? 'Rok povrata: ${formatDate(loan.dueDate)}' : 'Vraćeno: ${formatDate(loan.returnDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  loan.isOverdue
                      ? 'Kasni ${loan.daysOverdue} dana'
                      : Labels.loanStatus(loan.status) + (loan.extensionCount > 0 ? ' (produženo)' : ''),
                  style: TextStyle(
                    color: loan.isOverdue ? scheme.error : null,
                    fontWeight: loan.isOverdue ? FontWeight.bold : null,
                  ),
                ),
                Wrap(spacing: 8, children: [
                  if (loan.isActive && !loan.isOverdue && loan.extensionCount < 1)
                    OutlinedButton(onPressed: () => _extend(context, loan, reload), child: const Text('Produži')),
                  if (!loan.isActive && !loan.hasReview)
                    OutlinedButton.icon(
                      onPressed: () => _rate(context, loan, reload),
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Ocijeni'),
                    ),
                  if (!loan.isActive && loan.hasReview) const Chip(label: Text('Ocijenjeno')),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ReservationsTab extends StatelessWidget {
  const _ReservationsTab();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;

    return AsyncList<Reservation>(
      emptyText: 'Nemate rezervacija.',
      load: () async => (await api.myReservations(pageSize: 50)).items,
      itemBuilder: (context, r, reload) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: ListTile(
          leading: ApiImage(url: r.bookHasCover ? api.bookCoverUrl(r.bookId) : null, width: 44, height: 62),
          title: Text(r.bookTitle),
          subtitle: Text(
            '${Labels.reservationStatus(r.status)} · poslano ${formatDate(r.createdAt)}'
            '${r.status == 'Confirmed' ? '\nPreuzmite do ${formatDate(r.pickupDeadline)}' : ''}',
          ),
          isThreeLine: r.status == 'Confirmed',
          trailing: r.isOpen
              ? TextButton(
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      title: 'Otkazivanje rezervacije',
                      message: 'Otkazati rezervaciju knjige "${r.bookTitle}"?',
                      confirmText: 'Otkaži rezervaciju',
                    );
                    if (!ok || !context.mounted) return;
                    if (await runAction(context, () => api.cancelReservation(r.id), success: 'Rezervacija je otkazana.')) {
                      await reload();
                    }
                  },
                  child: const Text('Otkaži'),
                )
              : null,
        ),
      ),
    );
  }
}

class _FinesTab extends StatelessWidget {
  const _FinesTab();

  Future<void> _pay(BuildContext context, Fine fine, Future<void> Function() reload) async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => PayPalScreen(fine: fine)),
    );
    if (paid == true && context.mounted) {
      context.read<AppState>().refreshUnread();
    }
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final scheme = Theme.of(context).colorScheme;

    return AsyncList<Fine>(
      emptyText: 'Nemate zakasnina.',
      load: () async => (await api.myFines()).items,
      header: (fines) => fines.any((f) => f.isUnpaid)
          ? Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Text('Dok postoji neplaćena zakasnina, rezervacija i posudba novih knjiga nisu mogući. '
                  'Nakon uplate ograničenje se uklanja automatski.'),
            )
          : const SizedBox.shrink(),
      itemBuilder: (context, fine, reload) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ApiImage(url: fine.bookHasCover ? api.bookCoverUrl(fine.bookId) : null, width: 52, height: 74),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fine.bookTitle, style: Theme.of(context).textTheme.titleSmall),
                Text('Kašnjenje ${fine.daysLate} dana', style: Theme.of(context).textTheme.bodySmall),
                Text(formatKm(fine.amount), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  Labels.fineStatus(fine.status),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: fine.isUnpaid ? scheme.error : (fine.isPaid ? Colors.green.shade700 : scheme.outline),
                  ),
                ),
                if (fine.isPaid)
                  Text('Plaćeno ${formatDate(fine.paidAt)} (${Labels.paymentMethod(fine.paymentMethod)})',
                      style: Theme.of(context).textTheme.bodySmall),
                // Za plaćene zakasnine dugme "Plati" se ne prikazuje (isPaid).
                if (fine.isUnpaid && !fine.hasPendingPayment)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: FilledButton.icon(
                      onPressed: () => _pay(context, fine, reload),
                      icon: const Icon(Icons.payment),
                      label: const Text('Plati putem PayPal-a'),
                    ),
                  ),
                if (fine.isUnpaid && fine.hasPendingPayment) ...[
                  const Text('Plaćanje je započeto, ali nije završeno.'),
                  TextButton(
                    onPressed: () async {
                      if (await runAction(context, () => api.cancelPayment(fine.pendingPaymentId!),
                          success: 'Započeto plaćanje je otkazano.')) {
                        await reload();
                      }
                    },
                    child: const Text('Otkaži započeto plaćanje'),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({required this.title});

  final String title;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  final _comment = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: DialogTitle('Ocijenite: ${widget.title}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        RatingStars(rating: _rating.toDouble(), size: 36, onChanged: (v) => setState(() => _rating = v)),
        const SizedBox(height: 12),
        TextField(
          controller: _comment,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Komentar (nije obavezan)', border: OutlineInputBorder()),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
        FilledButton(
          onPressed: _rating == 0
              ? null
              : () => Navigator.pop(
                    context,
                    (_rating, _comment.text.trim().isEmpty ? null : _comment.text.trim()),
                  ),
          child: const Text('Pošalji'),
        ),
      ],
    );
  }
}
