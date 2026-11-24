import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/dialogs.dart';
import '../ui/paged_list_view.dart';
import '../ui/remote_picker.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final _listKey = GlobalKey<PagedListViewState<Loan>>();
  String? _filter;

  Future<void> _issue() async {
    final issued = await showDialog<bool>(context: context, builder: (_) => const _IssueLoanDialog());
    if (issued == true) {
      _listKey.currentState?.reload();
    }
  }

  Future<void> _return(Loan loan) async {
    final api = context.read<AppState>().api;

    // Pregled povrata: rok, datum povrata, dani kašnjenja i zakasnina koja će biti obračunata.
    ReturnPreview preview;
    try {
      preview = await api.returnPreview(loan.id);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      return;
    }
    if (!mounted) return;

    final fineText = preview.daysLate == 0
        ? 'Nema kašnjenja, zakasnina se ne obračunava.'
        : 'Kašnjenje: ${preview.daysLate} d., zakasnina: ${formatKm(preview.fineAmountKm)}.';
    final ok = await confirm(
      context,
      title: 'Povrat knjige',
      message: 'Evidentirati povrat knjige "${loan.bookTitle}" (${loan.userFullName})?\n\n'
          'Rok povrata: ${formatDate(preview.dueDate)}\n'
          'Datum povrata: ${formatDate(preview.returnDate)}\n'
          '$fineText',
      confirmText: 'Evidentiraj povrat',
    );
    if (!ok || !mounted) return;

    try {
      final returned = await api.returnLoan(loan.id);
      if (mounted) {
        showMessage(
          context,
          returned.fineId == null
              ? 'Povrat je evidentiran.'
              : 'Povrat je evidentiran. Knjiga je vraćena s kašnjenjem, obračunata je zakasnina.',
        );
      }
      _listKey.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final scheme = Theme.of(context).colorScheme;

    return PagedListView<Loan>(
      key: _listKey,
      searchHint: 'Knjiga, član ili broj karte',
      leading: [
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String?>(
            initialValue: _filter,
            decoration: const InputDecoration(labelText: 'Prikaz', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('Sve')),
              DropdownMenuItem<String?>(value: 'Active', child: Text('Aktivne')),
              DropdownMenuItem<String?>(value: 'Overdue', child: Text('Kasne')),
              DropdownMenuItem<String?>(value: 'Returned', child: Text('Vraćene')),
            ],
            onChanged: (v) {
              setState(() => _filter = v);
              _listKey.currentState?.load(page: 1);
            },
          ),
        ),
      ],
      trailing: [
        FilledButton.icon(onPressed: _issue, icon: const Icon(Icons.add), label: const Text('Izdaj knjigu')),
      ],
      columns: const ['', 'Knjiga', 'Član', 'Posuđeno', 'Rok povrata', 'Vraćeno', 'Status', ''],
      fetch: (page, search) => api.loans(page: page, search: search, filter: _filter),
      rowBuilder: (loan, reload) => DataRow(cells: [
        DataCell(ApiImage(url: loan.bookHasCover ? api.bookCoverUrl(loan.bookId) : null, width: 30, height: 42)),
        DataCell(SizedBox(width: 200, child: Text(loan.bookTitle, overflow: TextOverflow.ellipsis))),
        DataCell(Text('${loan.userFullName}\n${loan.membershipNumber}', style: Theme.of(context).textTheme.bodySmall)),
        DataCell(Text(formatDate(loan.loanDate))),
        DataCell(Text(formatDate(loan.dueDate))),
        DataCell(Text(formatDate(loan.returnDate))),
        DataCell(loan.isOverdue
            ? Text('Kasni ${loan.daysOverdue} d.', style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold))
            : Text(Labels.loanStatus(loan.status))),
        DataCell(loan.isActive
            ? TextButton(onPressed: () => _return(loan), child: const Text('Povrat'))
            : const SizedBox.shrink()),
      ]),
    );
  }
}

/// Izdavanje knjige: preuzimanje potvrđene rezervacije ili direktno izdavanje članu na šalteru.
class _IssueLoanDialog extends StatefulWidget {
  const _IssueLoanDialog();

  @override
  State<_IssueLoanDialog> createState() => _IssueLoanDialogState();
}

class _IssueLoanDialogState extends State<_IssueLoanDialog> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  List<Reservation> _confirmed = [];
  int? _reservationId;
  Member? _member;
  BookItem? _book;
  IssueCheck? _check;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  LibraryApi get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _loadConfirmed();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadConfirmed() async {
    try {
      final page = await _api.reservations(status: 'Confirmed', pageSize: 50);
      if (mounted) {
        setState(() {
          _confirmed = page.items;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  bool get _canSubmit =>
      _tabs.index == 0 ? _reservationId != null : (_member != null && _book != null && _check?.canIssue == true);

  /// Provjera pravila za odabranog člana i knjigu: prikazuje se prije snimanja.
  Future<void> _runCheck() async {
    setState(() => _check = null);
    final member = _member;
    final book = _book;
    if (member == null || book == null) return;

    try {
      final check = await _api.issueCheck(member.id, book.id);
      if (mounted && _member?.id == member.id && _book?.id == book.id) setState(() => _check = check);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_tabs.index == 0) {
        await _api.issueLoan(reservationId: _reservationId);
      } else {
        await _api.issueLoan(userId: _member!.id, bookId: _book!.id);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: DialogTitle('Izdavanje knjige'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(children: [
          TabBar(
            controller: _tabs,
            onTap: (_) => setState(() => _error = null),
            tabs: const [Tab(text: 'Iz rezervacije'), Tab(text: 'Direktno na šalteru')],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_fromReservation(), _direct()],
            ),
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Otkaži')),
        ListenableBuilder(
          listenable: _tabs,
          builder: (context, _) => FilledButton(
            onPressed: _saving || !_canSubmit ? null : _submit,
            child: const Text('Izdaj'),
          ),
        ),
      ],
    );
  }

  Widget _fromReservation() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_confirmed.isEmpty) return const Center(child: Text('Nema potvrđenih rezervacija za preuzimanje.'));

    return RadioGroup<int>(
      groupValue: _reservationId,
      onChanged: (v) => setState(() => _reservationId = v),
      child: ListView(children: [
        for (final r in _confirmed)
          RadioListTile<int>(
            value: r.id,
            title: Text(r.bookTitle),
            subtitle: Text('${r.userFullName} (${r.membershipNumber}) · preuzimanje do ${formatDate(r.pickupDeadline)}'),
          ),
      ]),
    );
  }

  Widget _checkPanel(IssueCheck check) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      key: const ValueKey('issue-check'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Provjera pravila', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text('Aktivne posudbe člana: ${check.activeLoans} od ${check.maxActiveLoans}'),
          Text('Neplaćene zakasnine: ${check.unpaidFines}'),
          Text('Slobodnih primjeraka: ${check.availableCopies}'),
          const SizedBox(height: 6),
          if (check.canIssue)
            const Text('Sva pravila su ispunjena.', style: TextStyle(fontWeight: FontWeight.w600))
          else
            for (final problem in check.problems) Text(problem, style: TextStyle(color: scheme.error)),
        ]),
      ),
    );
  }

  Widget _direct() {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        if (_member != null)
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(_member!.fullName),
            subtitle: Text(_member!.membershipNumber),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _member = null);
                _runCheck();
              },
            ),
          )
        else
          RemotePicker<Member>(
            label: 'Član',
            hint: 'Ime, prezime ili broj karte',
            search: (text) async => (await _api.members(search: text, pageSize: 10)).items,
            display: (m) => '${m.fullName} (${m.membershipNumber})',
            onSelected: (m) {
              setState(() => _member = m);
              _runCheck();
            },
          ),
        const SizedBox(height: 16),
        if (_book != null)
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(_book!.title),
            subtitle: Text('Dostupno: ${_book!.availableCopies} od ${_book!.totalCopies}'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _book = null);
                _runCheck();
              },
            ),
          )
        else
          RemotePicker<BookItem>(
            label: 'Knjiga',
            hint: 'Naslov ili autor',
            search: (text) async => (await _api.books(search: text, pageSize: 10)).items,
            display: (b) => '${b.title} (dostupno: ${b.availableCopies})',
            onSelected: (b) {
              setState(() => _book = b);
              _runCheck();
            },
          ),
        const SizedBox(height: 12),
        if (_check != null) _checkPanel(_check!),
        const SizedBox(height: 8),
        const Text('Rok povrata je 14 dana od danas.'),
      ]),
    );
  }
}
