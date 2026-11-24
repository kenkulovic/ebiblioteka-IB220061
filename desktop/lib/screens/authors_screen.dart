import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/dialogs.dart';
import '../ui/paged_list_view.dart';

class AuthorsScreen extends StatefulWidget {
  const AuthorsScreen({super.key});

  @override
  State<AuthorsScreen> createState() => _AuthorsScreenState();
}

class _AuthorsScreenState extends State<AuthorsScreen> {
  final _listKey = GlobalKey<PagedListViewState<Author>>();

  Future<void> _edit(Author? author) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _AuthorDialog(author: author));
    if (saved == true) {
      _listKey.currentState?.reload();
    }
  }

  Future<void> _delete(Author author) async {
    final ok = await confirm(
      context,
      title: 'Brisanje autora',
      message: 'Obrisati autora "${author.fullName}"?',
      confirmText: 'Obriši',
    );
    if (!ok || !mounted) return;

    final api = context.read<AppState>().api;
    final deleted = await runAction(context, () => api.deleteAuthor(author.id), success: 'Autor je obrisan.');
    if (deleted) {
      _listKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;

    return PagedListView<Author>(
      key: _listKey,
      searchHint: 'Ime ili prezime',
      trailing: [
        FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('Novi autor')),
      ],
      columns: const ['Ime i prezime', 'Država', 'Knjiga u katalogu', 'Biografija', ''],
      fetch: (page, search) => api.authors(page: page, search: search),
      rowBuilder: (author, reload) => DataRow(cells: [
        DataCell(Text(author.fullName)),
        DataCell(Text(author.countryName)),
        DataCell(Text('${author.bookCount}')),
        DataCell(SizedBox(width: 320, child: Text(author.biography ?? '—', overflow: TextOverflow.ellipsis))),
        DataCell(Row(children: [
          IconButton(tooltip: 'Izmijeni', onPressed: () => _edit(author), icon: const Icon(Icons.edit)),
          IconButton(
            tooltip: author.bookCount > 0
                ? 'Autor ima ${author.bookCount} knjiga i ne može se obrisati. Prvo uklonite ili izmijenite te knjige.'
                : 'Obriši',
            onPressed: author.bookCount > 0 ? null : () => _delete(author),
            icon: const Icon(Icons.delete_outline),
          ),
        ])),
      ]),
    );
  }
}

class _AuthorDialog extends StatefulWidget {
  const _AuthorDialog({this.author});

  final Author? author;

  @override
  State<_AuthorDialog> createState() => _AuthorDialogState();
}

class _AuthorDialogState extends State<_AuthorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.author?.firstName);
  late final _last = TextEditingController(text: widget.author?.lastName);
  late final _bio = TextEditingController(text: widget.author?.biography);

  List<Lookup> _countries = [];
  int? _countryId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _countryId = widget.author?.countryId;
    _loadCountries();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final page = await context.read<AppState>().api.lookups('countries', pageSize: 50);
      if (mounted) {
        setState(() {
          _countries = page.items;
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

    final api = context.read<AppState>().api;
    final bio = _bio.text.trim().isEmpty ? null : _bio.text.trim();

    try {
      if (widget.author == null) {
        await api.createAuthor(_first.text.trim(), _last.text.trim(), bio, _countryId!);
      } else {
        await api.updateAuthor(widget.author!.id, _first.text.trim(), _last.text.trim(), bio, _countryId!);
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
      title: DialogTitle(widget.author == null ? 'Novi autor' : 'Izmjena autora'),
      content: SizedBox(
        width: 460,
        child: _loading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                      controller: _first,
                      decoration: const InputDecoration(labelText: 'Ime *', border: OutlineInputBorder()),
                      maxLength: 50,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ime je obavezno.' : null,
                    ),
                    TextFormField(
                      controller: _last,
                      decoration: const InputDecoration(labelText: 'Prezime *', border: OutlineInputBorder()),
                      maxLength: 50,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Prezime je obavezno.' : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _countryId,
                      decoration: const InputDecoration(labelText: 'Država *', border: OutlineInputBorder()),
                      items: [for (final c in _countries) DropdownMenuItem(value: c.id, child: Text(c.name))],
                      onChanged: (v) => setState(() => _countryId = v),
                      validator: (v) => v == null ? 'Odaberite državu.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bio,
                      decoration: const InputDecoration(labelText: 'Biografija', border: OutlineInputBorder()),
                      maxLines: 4,
                      maxLength: 1000,
                    ),
                    if (_error != null)
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ]),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Otkaži')),
        FilledButton(onPressed: _saving || _loading ? null : _save, child: const Text('Sačuvaj')),
      ],
    );
  }
}
