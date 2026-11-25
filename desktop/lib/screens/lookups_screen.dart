import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/dialogs.dart';
import '../ui/paged_list_view.dart';

/// Šifarnici: države, gradovi, kategorije i izdavači (CRUD).
class LookupsScreen extends StatelessWidget {
  const LookupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;

    Future<List<(int, String)>> countries() async =>
        (await api.lookups('countries', pageSize: 50)).items.map((c) => (c.id, c.name)).toList();
    Future<List<(int, String)>> cities() async =>
        (await api.cities(pageSize: 50)).items.map((c) => (c.id, '${c.name} (${c.countryName})')).toList();

    return DefaultTabController(
      length: 4,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'Kategorije'), Tab(text: 'Gradovi'), Tab(text: 'Države'), Tab(text: 'Izdavači')]),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(children: [
            _LookupTab<Lookup>(
              singular: 'kategoriju',
              fetch: (page, search) => api.lookups('categories', page: page, search: search, newestFirst: true),
              idOf: (c) => c.id,
              nameOf: (c) => c.name,
              usageOf: (c) => c.usageCount,
              create: (name, _) => api.createLookup('categories', name),
              update: (id, name, _) => api.updateLookup('categories', id, name),
              delete: (id) => api.deleteLookup('categories', id),
            ),
            _LookupTab<City>(
              singular: 'grad',
              referenceLabel: 'Država',
              loadReferences: countries,
              fetch: (page, search) => api.cities(page: page, search: search, newestFirst: true),
              idOf: (c) => c.id,
              nameOf: (c) => c.name,
              usageOf: (c) => c.usageCount,
              referenceTextOf: (c) => c.countryName,
              referenceIdOf: (c) => c.countryId,
              create: (name, ref) => api.createCity(name, ref!),
              update: (id, name, ref) => api.updateCity(id, name, ref!),
              delete: (id) => api.deleteCity(id),
            ),
            _LookupTab<Lookup>(
              singular: 'državu',
              fetch: (page, search) => api.lookups('countries', page: page, search: search, newestFirst: true),
              idOf: (c) => c.id,
              nameOf: (c) => c.name,
              usageOf: (c) => c.usageCount,
              create: (name, _) => api.createLookup('countries', name),
              update: (id, name, _) => api.updateLookup('countries', id, name),
              delete: (id) => api.deleteLookup('countries', id),
            ),
            _LookupTab<Publisher>(
              singular: 'izdavača',
              maxLength: 150,
              referenceLabel: 'Grad',
              loadReferences: cities,
              fetch: (page, search) => api.publishers(page: page, search: search, newestFirst: true),
              idOf: (p) => p.id,
              nameOf: (p) => p.name,
              usageOf: (p) => p.usageCount,
              referenceTextOf: (p) => p.cityName,
              referenceIdOf: (p) => p.cityId,
              create: (name, ref) => api.createPublisher(name, ref!),
              update: (id, name, ref) => api.updatePublisher(id, name, ref!),
              delete: (id) => api.deletePublisher(id),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _LookupTab<T> extends StatefulWidget {
  const _LookupTab({
    required this.singular,
    required this.fetch,
    required this.idOf,
    required this.nameOf,
    required this.usageOf,
    required this.create,
    required this.update,
    required this.delete,
    this.maxLength = 100,
    this.referenceLabel,
    this.loadReferences,
    this.referenceTextOf,
    this.referenceIdOf,
  });

  /// Tuzilac jednine ("državu") za naslove, npr. "Dodaj državu".
  final String singular;
  final int maxLength;
  final String? referenceLabel;
  final Future<List<(int, String)>> Function()? loadReferences;

  final Future<PagedResult<T>> Function(int page, String search) fetch;
  final int Function(T item) idOf;
  final String Function(T item) nameOf;

  /// Broj zapisa koji koriste stavku; ako je veći od nule, brisanje je onemogućeno.
  final int Function(T item) usageOf;
  final String Function(T item)? referenceTextOf;
  final int Function(T item)? referenceIdOf;
  final Future<void> Function(String name, int? referenceId) create;
  final Future<void> Function(int id, String name, int? referenceId) update;
  final Future<void> Function(int id) delete;

  @override
  State<_LookupTab<T>> createState() => _LookupTabState<T>();
}

class _LookupTabState<T> extends State<_LookupTab<T>> with AutomaticKeepAliveClientMixin {
  final _listKey = GlobalKey<PagedListViewState<T>>();

  @override
  bool get wantKeepAlive => true;

  Future<void> _edit(T? item) async {
    // Forma se ne otvara dok ne postoji zapis na koji se stavka mora vezati (npr. država za grad).
    if (widget.loadReferences != null) {
      try {
        final references = await widget.loadReferences!();
        if (!mounted) return;
        if (references.isEmpty) {
          showMessage(context, 'Prvo dodajte stavku "${widget.referenceLabel}".', error: true);
          return;
        }
      } on ApiException catch (e) {
        if (mounted) showMessage(context, e.message, error: true);
        return;
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _LookupFormDialog(
        title: item == null ? 'Dodaj ${widget.singular}' : 'Izmjena',
        initialName: item == null ? null : widget.nameOf(item),
        maxLength: widget.maxLength,
        referenceLabel: widget.referenceLabel,
        loadReferences: widget.loadReferences,
        initialReferenceId: item == null ? null : widget.referenceIdOf?.call(item),
        save: (name, ref) =>
            item == null ? widget.create(name, ref) : widget.update(widget.idOf(item), name, ref),
      ),
    );
    if (saved == true) _listKey.currentState?.load(page: item == null ? 1 : null);
  }

  Future<void> _delete(T item) async {
    final ok = await confirm(
      context,
      title: 'Brisanje',
      message: 'Obrisati "${widget.nameOf(item)}"?',
      confirmText: 'Obriši',
    );
    if (!ok || !mounted) return;

    // Ako se zapis koristi, server vraca poruku s razlogom (npr. "koriste gradovi ili autori").
    final done = await runAction(context, () => widget.delete(widget.idOf(item)), success: 'Obrisano.');
    if (done) _listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PagedListView<T>(
      key: _listKey,
      searchHint: 'Pretraga po nazivu',
      trailing: [
        FilledButton.icon(
          onPressed: () => _edit(null),
          icon: const Icon(Icons.add),
          label: Text('Dodaj ${widget.singular}'),
        ),
      ],
      columns: ['Naziv', if (widget.referenceLabel != null) widget.referenceLabel!, 'U upotrebi', ''],
      fetch: widget.fetch,
      rowBuilder: (item, reload) => DataRow(cells: [
        DataCell(Text(widget.nameOf(item))),
        if (widget.referenceTextOf != null) DataCell(Text(widget.referenceTextOf!(item))),
        DataCell(Text('${widget.usageOf(item)}')),
        DataCell(Row(children: [
          IconButton(tooltip: 'Izmijeni', onPressed: () => _edit(item), icon: const Icon(Icons.edit)),
          IconButton(
            tooltip: widget.usageOf(item) > 0
                ? 'Stavka se koristi u ${widget.usageOf(item)} zapisa i ne može se obrisati.'
                : 'Obriši',
            onPressed: widget.usageOf(item) > 0 ? null : () => _delete(item),
            icon: const Icon(Icons.delete_outline),
          ),
        ])),
      ]),
    );
  }
}

class _LookupFormDialog extends StatefulWidget {
  const _LookupFormDialog({
    required this.title,
    required this.maxLength,
    required this.save,
    this.initialName,
    this.referenceLabel,
    this.loadReferences,
    this.initialReferenceId,
  });

  final String title;
  final String? initialName;
  final int maxLength;
  final String? referenceLabel;
  final Future<List<(int, String)>> Function()? loadReferences;
  final int? initialReferenceId;
  final Future<void> Function(String name, int? referenceId) save;

  @override
  State<_LookupFormDialog> createState() => _LookupFormDialogState();
}

class _LookupFormDialogState extends State<_LookupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);

  List<(int, String)> _references = [];
  int? _referenceId;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _referenceId = widget.initialReferenceId;
    if (widget.loadReferences != null) {
      _loading = true;
      _loadReferences();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    try {
      final references = await widget.loadReferences!();
      if (mounted) {
        setState(() {
          _references = references;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.save(_name.text.trim(), _referenceId);
      if (mounted) {
        showMessage(context, 'Stavka "${_name.text.trim()}" je sačuvana.');
        Navigator.pop(context, true);
      }
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
      title: DialogTitle(widget.title),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    maxLength: widget.maxLength,
                    decoration: const InputDecoration(labelText: 'Naziv *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Naziv je obavezan.' : null,
                  ),
                  if (widget.referenceLabel != null) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _referenceId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: '${widget.referenceLabel} *',
                        border: const OutlineInputBorder(),
                      ),
                      items: [for (final (id, name) in _references) DropdownMenuItem(value: id, child: Text(name))],
                      onChanged: (v) => setState(() => _referenceId = v),
                      validator: (v) => v == null ? 'Odaberite vrijednost.' : null,
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                ]),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Otkaži')),
        FilledButton(onPressed: _saving || _loading ? null : _save, child: const Text('Sačuvaj')),
      ],
    );
  }
}
