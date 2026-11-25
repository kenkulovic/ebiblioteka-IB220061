import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/async_list.dart';
import '../ui/dialogs.dart';
import 'loan_details_screen.dart';
import 'paypal_screen.dart';

/// Moje knjige: posudbe (master-details), rezervacije i zakasnine (plaćanje).
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
          title: const Text('Moje posudbe'),
          bottom: const TabBar(tabs: [Tab(text: 'Posudbe'), Tab(text: 'Rezervacije'), Tab(text: 'Zakasnine')]),
        ),
        body: const TabBarView(children: [_LoansTab(), _ReservationsTab(), _FinesTab()]),
      ),
    );
  }
}

class _LoansTab extends StatelessWidget {
  const _LoansTab();

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final scheme = Theme.of(context).colorScheme;

    // Master dio: lista posudbi; dodir otvara detalje posudbe.
    return AsyncList<Loan>(
      emptyText: 'Nemate posudbi.',
      load: () async => (await api.myLoans(pageSize: 50)).items,
      itemBuilder: (context, loan, reload) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: InkWell(
          key: ValueKey('loan-${loan.id}'),
          onTap: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => LoanDetailsScreen(loan: loan)),
            );
            await reload();
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ApiImage(url: loan.bookHasCover ? api.bookCoverUrl(loan.bookId) : null, width: 52, height: 74),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loan.bookTitle, style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    'Rok povrata: ${formatDate(loan.dueDate)}'
                    '${loan.isActive ? '' : '\nVraćeno: ${formatDate(loan.returnDate)}'}',
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
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
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
            '${r.status == 'Confirmed' ? '\nPreuzmite do ${formatDate(r.pickupDeadline)}' : ''}'
            '${r.status == 'Cancelled' && r.cancelReason != null ? '\nRazlog: ${r.cancelReason}' : ''}',
          ),
          isThreeLine: r.status == 'Confirmed' || (r.status == 'Cancelled' && r.cancelReason != null),
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
    final paid = await PayPalScreen.pay(context, fine);
    if (paid && context.mounted) {
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
      load: () async {
        final fines = (await api.myFines()).items;
        return [...fines.where((f) => f.isUnpaid), ...fines.where((f) => !f.isUnpaid)];
      },
      sectionOf: (fine) => fine.isUnpaid ? 'Neplaćene' : 'Plaćene i stornirane',
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
                Text('${formatKm(fine.amount)} (${formatEur(fine.amountEur)})',
                    style: Theme.of(context).textTheme.titleMedium),
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
                      final yes = await confirm(
                        context,
                        title: 'Otkazivanje plaćanja',
                        message: 'Otkazati započeto plaćanje ove zakasnine?',
                        confirmText: 'Otkaži plaćanje',
                      );
                      if (!yes || !context.mounted) return;
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
