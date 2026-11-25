import 'dart:typed_data';

import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/dialogs.dart';
import '../ui/quick_add_dialogs.dart';
import '../ui/remote_picker.dart';
import 'authors_screen.dart';

/// Dodavanje (bookId == null) i izmjena knjige, zajedno s naslovnicom.
class BookFormDialog extends StatefulWidget {
  const BookFormDialog({super.key, this.bookId});

  final int? bookId;

  @override
  State<BookFormDialog> createState() => _BookFormDialogState();
}

class _BookFormDialogState extends State<BookFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _year = TextEditingController();
  final _pages = TextEditingController();
  final _description = TextEditingController();
  final _copies = TextEditingController(text: '1');

  List<Lookup> _categories = [];
  List<Publisher> _publishers = [];
  final List<BookAuthor> _authors = [];

  int? _categoryId;
  int? _publisherId;
  bool _hadCover = false;
  bool _removeCover = false;
  Uint8List? _newCover;
  String _newCoverName = 'naslovnica.png';

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _authorsError;

  LibraryApi get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _year, _pages, _description, _copies]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final categories = await _api.lookups('categories', pageSize: 50);
      final publishers = await _api.publishers(pageSize: 50);

      if (widget.bookId != null) {
        final book = await _api.book(widget.bookId!);
        _title.text = book.title;
        _year.text = book.publishedYear?.toString() ?? '';
        _pages.text = book.pageCount?.toString() ?? '';
        _description.text = book.description ?? '';
        _copies.text = book.totalCopies.toString();
        _categoryId = book.categoryId;
        _publisherId = book.publisherId;
        _authors.addAll(book.authors);
        _hadCover = book.hasCover;
      }

      if (!mounted) return;
      setState(() {
        _categories = categories.items;
        _publishers = publishers.items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _addAuthor(Author author) {
    if (_authors.every((x) => x.id != author.id)) {
      setState(() {
        _authors.add(BookAuthor.fromJson({'id': author.id, 'fullName': author.fullName}));
        _authorsError = null;
      });
    }
  }

  // Brzo dodavanje: novi zapis se odmah bira u formi, bez napuštanja unosa knjige.
  Future<void> _createAuthor() async {
    final created = await showDialog<Author>(context: context, builder: (_) => const AuthorDialog());
    if (created != null) _addAuthor(created);
  }

  Future<void> _addCategory() async {
    final created = await showDialog<Lookup>(context: context, builder: (_) => const QuickAddCategoryDialog());
    if (created != null && mounted) {
      setState(() {
        _categories = [..._categories, created];
        _categoryId = created.id;
      });
    }
  }

  Future<void> _addPublisher() async {
    final created = await showDialog<Publisher>(context: context, builder: (_) => const QuickAddPublisherDialog());
    if (created != null && mounted) {
      setState(() {
        _publishers = [..._publishers, created];
        _publisherId = created.id;
      });
    }
  }

  Future<void> _pickCover() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _newCover = bytes;
      _newCoverName = file.name;
      _removeCover = false;
    });
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _authorsError = _authors.isEmpty ? 'Dodajte barem jednog autora.' : null);
    if (!valid || _authors.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final body = _api.bookBody(
        title: _title.text.trim(),
        publishedYear: int.tryParse(_year.text.trim()),
        pageCount: int.tryParse(_pages.text.trim()),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        totalCopies: int.parse(_copies.text.trim()),
        categoryId: _categoryId!,
        publisherId: _publisherId,
        authorIds: _authors.map((a) => a.id).toList(),
      );

      final saved = widget.bookId == null ? await _api.createBook(body) : await _api.updateBook(widget.bookId!, body);

      if (_newCover != null) {
        await _api.setBookCover(saved.id, _newCoverName, _newCover!);
      } else if (_removeCover && _hadCover) {
        await _api.removeBookCover(saved.id);
      }

      if (mounted) {
        showMessage(context, 'Knjiga "${saved.title}" je sačuvana.');
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
      title: DialogTitle(widget.bookId == null ? 'Nova knjiga' : 'Izmjena knjige'),
      content: SizedBox(width: 640, child: _loading ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())) : _form()),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Otkaži')),
        FilledButton(onPressed: _saving || _loading ? null : _save, child: const Text('Sačuvaj')),
      ],
    );
  }

  Widget _form() {
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  if (_newCover != null)
                    Image.memory(_newCover!, width: 110, height: 156, fit: BoxFit.cover)
                  else
                    ApiImage(
                      url: (widget.bookId != null && _hadCover && !_removeCover) ? _api.bookCoverUrl(widget.bookId!) : null,
                      width: 110,
                      height: 156,
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _pickCover, child: const Text('Naslovnica...')),
                  if (_newCover != null || (_hadCover && !_removeCover))
                    TextButton(
                      onPressed: () => setState(() {
                        _newCover = null;
                        _removeCover = true;
                      }),
                      child: const Text('Ukloni'),
                    ),
                ]),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(children: [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Naslov *', border: OutlineInputBorder()),
                      maxLength: 200,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Naslov je obavezan.' : null,
                    ),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _year,
                          decoration: const InputDecoration(labelText: 'Godina izdanja', border: OutlineInputBorder(), errorMaxLines: 3),
                          keyboardType: TextInputType.number,
                          validator: (v) => _optionalRange(v, 1000, 2100, 'Unesite godinu od 1000 do 2100.'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _pages,
                          decoration: const InputDecoration(labelText: 'Broj stranica', border: OutlineInputBorder(), errorMaxLines: 3),
                          keyboardType: TextInputType.number,
                          validator: (v) => _optionalRange(v, 1, 20000, 'Unesite broj stranica od 1 do 20000.'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _copies,
                          decoration: const InputDecoration(labelText: 'Primjeraka *', border: OutlineInputBorder(), errorMaxLines: 3),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            return (n == null || n < 1 || n > 1000) ? 'Unesite broj primjeraka od 1 do 1000.' : null;
                          },
                        ),
                      ),
                    ]),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('book-category-$_categoryId-${_categories.length}'),
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategorija *', border: OutlineInputBorder()),
                  items: [for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) => v == null ? 'Odaberite kategoriju.' : null,
                ),
              ),
              IconButton(
                key: const ValueKey('book-add-category'),
                tooltip: 'Nova kategorija',
                onPressed: _addCategory,
                icon: const Icon(Icons.add_circle_outline),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  key: ValueKey('book-publisher-$_publisherId-${_publishers.length}'),
                  initialValue: _publisherId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Izdavač', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('—')),
                    for (final p in _publishers) DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setState(() => _publisherId = v),
                ),
              ),
              IconButton(
                key: const ValueKey('book-add-publisher'),
                tooltip: 'Novi izdavač',
                onPressed: _addPublisher,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
            const SizedBox(height: 16),
            Text('Autori *', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final a in _authors)
                InputChip(label: Text(a.fullName), onDeleted: () => setState(() => _authors.remove(a))),
              if (_authors.isEmpty) Text('Nijedan autor nije dodan.', style: TextStyle(color: scheme.outline)),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: RemotePicker<Author>(
                  label: 'Dodaj autora',
                  search: (text) async => (await _api.authors(search: text, pageSize: 10)).items,
                  display: (a) => a.fullName,
                  onSelected: _addAuthor,
                ),
              ),
              IconButton(
                key: const ValueKey('book-add-author'),
                tooltip: 'Novi autor',
                onPressed: _createAuthor,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
            if (_authorsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_authorsError!, style: TextStyle(color: scheme.error)),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Opis', border: OutlineInputBorder()),
              maxLines: 3,
              maxLength: 2000,
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ),
      ),
    );
  }

  String? _optionalRange(String? value, int min, int max, String message) {
    if (value == null || value.trim().isEmpty) return null;
    final n = int.tryParse(value.trim());
    return (n == null || n < min || n > max) ? message : null;
  }
}
