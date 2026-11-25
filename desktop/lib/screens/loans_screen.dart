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
  int? _dueWithinDays;

  Future<void> _issue() async {
    // Forma se ne otvara dok nisu ispunjeni preduslovi: moraju postojati i knjige i članovi.
    final api = context.read<AppState>().api;
    try {
      final books = await api.books(pageSize: 1);
      final members = await api.members(pageSize: 1);
      if (books.totalCount == 0 || members.totalCount == 0) {
        if (mounted) {
          showMessage(
            context,
            books.totalCount == 0
                ? 'Izdavanje nije moguće jer u sistemu nema knjiga. Prvo dodajte knjigu.'
                : 'Izdavanje nije moguće jer u sistemu nema članova. Članovi se registruju u mobilnoj aplikaciji.',
            error: true,
          );
        }
        return;
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      return;
    }
    if (!mounted) return;

    final issued = await showDialog<bool>(context: context, builder: (_) => const IssueLoanDialog());
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
        SizedBox(
          width: 210,
          child: DropdownButtonFormField<int?>(
            key: const ValueKey('loan-due-filter'),
            initialValue: _dueWithinDays,
            decoration: const InputDecoration(labelText: 'Rok povrata', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem<int?>(value: null, child: Text('Svi')),
              DropdownMenuItem<int?>(value: 0, child: Text('Ističe danas')),
              DropdownMenuItem<int?>(value: 3, child: Text('Ističe u 3 dana')),
              DropdownMenuItem<int?>(value: 7, child: Text('Ističe u 7 dana')),
            ],
            onChanged: (v) {
              setState(() => _dueWithinDays = v);
              _listKey.currentState?.load(page: 1);
            },
          ),
        ),
      ],
      trailing: [
        FilledButton.icon(onPressed: _issue, icon: const Icon(Icons.add), label: const Text('Izdaj knjigu')),
      ],
      columns: const ['', 'Knjiga', 'Član', 'Posuđeno', 'Rok povrata', 'Vraćeno', 'Status', ''],
      fetch: (page, search) => api.loans(page: page, search: search, filter: _filter, dueWithinDays: _dueWithinDays),
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
class IssueLoanDialog extends StatefulWidget {
  const IssueLoanDialog({super.key, this.reservationId});

  /// Potvrđena rezervacija koja je unaprijed odabrana (akcija "Preuzeto" u rezervacijama).
  final int? reservationId;

  @override
  State<IssueLoanDialog> createState() => _IssueLoanDialogState();
}

class _IssueLoanDialogState extends State<IssueLoanDialog> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  List<Reservation> _confirmed = [];
  int? _reservationId;
  IssueCheck? _reservationCheck;
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
        if (widget.reservationId != null) await _selectReservation(widget.reservationId);
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

  bool get _canSubmit => _tabs.index == 0
      ? _reservationId != null && _reservationCheck?.canIssue == true
      : (_member != null && _book != null && _check?.canIssue == true);

  /// Odabir rezervacije odmah pokreće provjeru pravila za tog člana i knjigu.
  Future<void> _selectReservation(int? id) async {
    final reservation = _confirmed.where((r) => r.id == id).firstOrNull;
    setState(() {
      _reservationId = reservation?.id;
      _reservationCheck = null;
    });
    if (reservation == null) return;

    try {
      final check = await _api.issueCheck(reservation.userId, reservation.bookId);
      if (mounted && _reservationId == id) setState(() => _reservationCheck = check);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

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
      onChanged: _selectReservation,
      child: ListView(children: [
        // Provjera pravila za odabranu rezervaciju prikazuje se na vrhu, prije snimanja.
        if (_reservationCheck != null) _checkPanel(_reservationCheck!),
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
          if (check.hasConfirmedReservation)
            const Text('Izdavanje se veže za potvrđenu rezervaciju člana, koja postaje završena.'),
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
