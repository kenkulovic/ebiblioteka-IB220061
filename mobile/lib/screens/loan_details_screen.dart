import 'dart:async';

import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/dialogs.dart';
import '../ui/rating_dialog.dart';
import 'my_library_screen.dart';
import 'paypal_screen.dart';

/// Detalji posudbe (details dio master-details prikaza): datumi, kašnjenje, zakasnina, produženje i ocjena.
class LoanDetailsScreen extends StatefulWidget {
  const LoanDetailsScreen({super.key, required this.loan});

  final Loan loan;

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  static const _autoRefresh = Duration(seconds: 20);

  late Loan _loan = widget.loan;
  Fine? _unpaidFine;
  Review? _review;
  Timer? _timer;

  LibraryApi get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(_autoRefresh, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final loans = await _api.myLoans(pageSize: 50);
      final loan = loans.items.where((l) => l.id == _loan.id).firstOrNull ?? _loan;

      Fine? unpaid;
      if (loan.fineStatus == 'Unpaid') {
        final fines = await _api.myFines();
        unpaid = fines.items.where((f) => f.loanId == loan.id && f.isUnpaid).firstOrNull;
      }

      Review? review;
      if (loan.hasReview) {
        final reviews = await _api.myReviews();
        review = reviews.items.where((r) => r.loanId == loan.id).firstOrNull;
      }

      if (!mounted) return;
      setState(() {
        _loan = loan;
        _unpaidFine = unpaid;
        _review = review;
      });
    } on ApiException {
      // Prikazuju se posljednji poznati podaci; greška se vidi pri sljedećoj radnji.
    }
  }

  Future<void> _extend() async {
    final ok = await confirm(
      context,
      title: 'Produženje posudbe',
      message: 'Produžiti posudbu knjige "${_loan.bookTitle}" za 7 dana? Moguće je samo jedno produženje.',
      confirmText: 'Produži',
    );
    if (!ok || !mounted) return;

    if (await runAction(context, () => _api.extendLoan(_loan.id), success: 'Posudba je produžena.')) {
      await _refresh();
    }
  }

  Future<void> _rate() async {
    final editing = _review != null;
    final result = await showDialog<(int, String?)>(
      context: context,
      builder: (_) => RatingDialog(
        title: _loan.bookTitle,
        initialRating: _review?.rating ?? 0,
        initialComment: _review?.comment,
        editing: editing,
      ),
    );
    if (result == null || !mounted) return;

    final saved = await runAction(
      context,
      () => editing
          ? _api.updateReview(_review!.id, result.$1, result.$2)
          : _api.createReview(_loan.id, result.$1, result.$2),
      success: editing ? 'Ocjena je izmijenjena.' : 'Hvala na ocjeni!',
    );
    if (saved) await _refresh();
  }

  Future<void> _pay(Fine fine) async {
    final paid = await PayPalScreen.pay(context, fine);
    if (paid && mounted) context.read<AppState>().refreshUnread();
    await _refresh();
  }

  int get _daysLate {
    if (_loan.isActive) return _loan.daysOverdue;
    final returned = _loan.returnDate;
    if (returned == null) return 0;
    final days = DateTime(returned.year, returned.month, returned.day)
        .difference(DateTime(_loan.dueDate.year, _loan.dueDate.month, _loan.dueDate.day))
        .inDays;
    return days > 0 ? days : 0;
  }

  Widget _row(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loan = _loan;
    final blockedReason = loan.extensionBlockedReason;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalji posudbe')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ApiImage(url: loan.bookHasCover ? _api.bookCoverUrl(loan.bookId) : null, width: 90, height: 128),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loan.bookTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                Labels.loanStatus(loan.status, overdue: loan.isOverdue),
                style: TextStyle(fontWeight: FontWeight.bold, color: loan.isOverdue ? scheme.error : null),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        const Divider(height: 1),
        _row(Icons.event, 'Datum posudbe', formatDate(loan.loanDate)),
        _row(Icons.event_available, 'Rok povrata', formatDate(loan.dueDate)),
        _row(Icons.assignment_returned, 'Datum povrata', loan.returnDate == null ? '—' : formatDate(loan.returnDate)),
        _row(Icons.timer_outlined, 'Dani kašnjenja', '$_daysLate', color: _daysLate > 0 ? scheme.error : null),
        _row(
          Icons.payments_outlined,
          'Zakasnina',
          loan.fineAmount == null ? 'Nema' : '${formatKm(loan.fineAmount!)} (${Labels.fineStatus(loan.fineStatus ?? '')})',
        ),
        _row(Icons.update, 'Iskorištena produženja', '${loan.extensionCount} od 1'),
        const Divider(height: 24),
        if (loan.isActive) ...[
          FilledButton.icon(
            key: const ValueKey('loan-extend'),
            onPressed: blockedReason == null ? _extend : null,
            icon: const Icon(Icons.update),
            label: const Text('Produži za 7 dana'),
          ),
          if (blockedReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(blockedReason, key: const ValueKey('loan-extend-reason'), style: TextStyle(color: scheme.outline)),
            ),
        ],
        if (!loan.isActive && !loan.hasReview)
          FilledButton.icon(
            key: const ValueKey('loan-rate'),
            onPressed: _rate,
            icon: const Icon(Icons.star_outline),
            label: const Text('Ocijeni knjigu'),
          ),
        if (!loan.isActive && loan.hasReview) ...[
          Text('Vaša ocjena', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          if (_review != null) ...[
            RatingStars(rating: _review!.rating.toDouble(), size: 24),
            if (_review!.comment != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_review!.comment!)),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('loan-edit-rating'),
            onPressed: _review == null ? null : _rate,
            icon: const Icon(Icons.edit),
            label: const Text('Izmijeni ocjenu'),
          ),
        ],
        if (loan.fineId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('loan-my-fines'),
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const MyLibraryScreen(initialTab: 2)),
                );
                await _refresh();
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Moje zakasnine'),
            ),
          ),
        if (_unpaidFine != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Za ovu posudbu postoji neplaćena zakasnina od ${formatKm(_unpaidFine!.amount)}.'),
                const SizedBox(height: 8),
                if (_unpaidFine!.hasPendingPayment)
                  const Text('Plaćanje je započeto, a može se završiti ili otkazati na kartici Zakasnine.')
                else
                  FilledButton.icon(
                    key: const ValueKey('loan-pay-fine'),
                    onPressed: () => _pay(_unpaidFine!),
                    icon: const Icon(Icons.payment),
                    label: const Text('Plati putem PayPal-a'),
                  ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
