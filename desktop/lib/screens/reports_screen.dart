import 'dart:typed_data';

import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../ui/dialogs.dart';

/// Izvještaji za odabrani period, s prikazom zbirnih podataka i izvozom u PDF.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTimeRange _range;
  int? _categoryId;
  String? _status;
  List<Lookup> _categories = [];

  LoanReport? _loans;
  FineReport? _fines;
  String? _error;
  bool _loading = false;

  LibraryApi get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _range = DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
      _load();
    });
  }

  Future<void> _loadCategories() async {
    try {
      final page = await _api.lookups('categories', pageSize: 100);
      if (mounted) setState(() => _categories = page.items);
    } on ApiException {
      // Bez liste kategorija izvještaj i dalje radi za sve kategorije.
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
      helpText: 'Odaberite period izvještaja',
      saveText: 'Primijeni',
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final loans = await _api.loanReport(_range.start, _range.end, categoryId: _categoryId);
      final fines = await _api.fineReport(_range.start, _range.end, status: _status);
      if (mounted) {
        setState(() {
          _loans = loans;
          _fines = fines;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(String name, Future<Uint8List> Function() download) async {
    try {
      final bytes = await download();
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Sačuvaj izvještaj',
        fileName: '$name-${_stamp(_range.start)}-${_stamp(_range.end)}.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (saved == null) return;

      if (!mounted) return;
      showMessage(context, 'Izvještaj je sačuvan: ${saved.toFilePath()}');
      await launchUrl(saved);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  String _stamp(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            label: Text('${formatDate(_range.start)} – ${formatDate(_range.end)}'),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<int?>(
              key: const ValueKey('report-category'),
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategorija', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Sve kategorije')),
                for (final c in _categories) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) {
                setState(() => _categoryId = v);
                _load();
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String?>(
              key: const ValueKey('report-status'),
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status zakasnina', border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('Svi statusi')),
                DropdownMenuItem<String?>(value: 'Unpaid', child: Text('Neplaćene')),
                DropdownMenuItem<String?>(value: 'Paid', child: Text('Plaćene')),
                DropdownMenuItem<String?>(value: 'Cancelled', child: Text('Stornirane')),
              ],
              onChanged: (v) {
                setState(() => _status = v);
                _load();
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(onPressed: _loading ? null : _load, child: const Text('Osvježi')),
          if (_loading) const Padding(padding: EdgeInsets.only(left: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ]),
        const SizedBox(height: 16),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_loans != null && _fines != null)
          Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.start, children: [
            _ReportCard(
              title: 'Izvještaj o posudbama',
              rows: [
                ('Ukupno posudbi', '${_loans!.totalLoans}'),
                ('Vraćeno', '${_loans!.returned}'),
                ('Još aktivno', '${_loans!.active}'),
                ('Od toga kasni', '${_loans!.overdueNow}'),
                (
                  'Prosječno trajanje (dana)',
                  _loans!.averageLoanDays?.toStringAsFixed(1).replaceAll('.', ',') ?? '—'
                ),
              ],
              extra: [
                if (_loans!.topBooks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('10 najposuđivanijih knjiga (posudbi, prosječna ocjena)',
                      style: Theme.of(context).textTheme.labelLarge),
                  for (final b in _loans!.topBooks)
                    Text('${b.name}: ${b.count}, ${b.averageRating?.toStringAsFixed(1).replaceAll('.', ',') ?? '—'}'),
                ],
                if (_loans!.byCategory.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Posudbe po kategorijama', style: Theme.of(context).textTheme.labelLarge),
                  for (final c in _loans!.byCategory) Text('${c.name}: ${c.count}'),
                ],
              ],
              onPdf: () => _export(
                  'izvjestaj-posudbe', () => _api.loanReportPdf(_range.start, _range.end, categoryId: _categoryId)),
            ),
            _ReportCard(
              title: 'Izvještaj o zakasninama i uplatama',
              rows: [
                ('Ukupno zakasnina', '${_fines!.totalFines} (${formatKm(_fines!.totalAmountKm)})'),
                ('Neplaćene', '${_fines!.unpaid.count} (${formatKm(_fines!.unpaid.amountKm)})'),
                ('Plaćene', '${_fines!.paid.count} (${formatKm(_fines!.paid.amountKm)})'),
                ('Stornirane', '${_fines!.cancelled.count} (${formatKm(_fines!.cancelled.amountKm)})'),
                ('Naplaćeno putem PayPal-a', formatKm(_fines!.paidPayPalKm)),
                ('Naplaćeno na šalteru', formatKm(_fines!.paidCounterKm)),
                ('Vraćene uplate', '${_fines!.refundedCount} (${formatEur(_fines!.refundedEur)})'),
                (
                  'Prosječno kašnjenje (dana)',
                  _fines!.averageDaysLate?.toStringAsFixed(1).replaceAll('.', ',') ?? '—'
                ),
              ],
              extra: [
                if (_fines!.members.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Članovi sa zakasninama (broj, ukupno, neplaćeno)',
                      style: Theme.of(context).textTheme.labelLarge),
                  for (final m in _fines!.members.take(10))
                    Text('${m.member}: ${m.count}, ${formatKm(m.totalKm)}, ${formatKm(m.unpaidKm)}'),
                  if (_fines!.members.length > 10)
                    Text('... i još ${_fines!.members.length - 10} (kompletna lista je u PDF-u)'),
                ],
              ],
              onPdf: () =>
                  _export('izvjestaj-zakasnine', () => _api.fineReportPdf(_range.start, _range.end, status: _status)),
            ),
          ]),
      ]),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.rows, required this.onPdf, this.extra = const []});

  final String title;
  final List<(String, String)> rows;
  final List<Widget> extra;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 460,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(label)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            ...extra,
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Izvezi u PDF'),
            ),
          ]),
        ),
      ),
    );
  }
}
