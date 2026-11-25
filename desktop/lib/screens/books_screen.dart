import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/dialogs.dart';
import '../ui/paged_list_view.dart';
import 'book_form_dialog.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final _listKey = GlobalKey<PagedListViewState<BookItem>>();

  List<Lookup> _categories = [];
  int? _categoryId;
  bool? _available;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final api = context.read<AppState>().api;
    try {
      final page = await api.lookups('categories', pageSize: 50);
      if (mounted) {
        setState(() => _categories = page.items);
      }
    } on ApiException {
      // Filter po kategoriji je opcionalan: bez kategorija tabela radi i dalje.
    }
  }

  Future<void> _edit(BookItem? book) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => BookFormDialog(bookId: book?.id),
    );
    if (saved == true) {
      // Nova knjiga je na vrhu prve strane; nakon izmjene ostaje se na istoj strani.
      _listKey.currentState?.load(page: book == null ? 1 : null);
    }
  }

  Future<void> _delete(BookItem book) async {
    final ok = await confirm(
      context,
      title: 'Brisanje knjige',
      message: 'Obrisati knjigu "${book.title}"?',
      confirmText: 'Obriši',
    );
    if (!ok || !mounted) return;

    final api = context.read<AppState>().api;
    final deleted = await runAction(context, () => api.deleteBook(book.id), success: 'Knjiga je obrisana.');
    if (deleted) {
      _listKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;

    return PagedListView<BookItem>(
      key: _listKey,
      searchHint: 'Naslov ili autor',
      leading: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<int?>(
            initialValue: _categoryId,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Kategorija', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Sve')),
              for (final c in _categories) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (value) {
              setState(() => _categoryId = value);
              _listKey.currentState?.load(page: 1);
            },
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<bool?>(
            key: const ValueKey('book-availability'),
            initialValue: _available,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Dostupnost', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('Sve')),
              DropdownMenuItem<bool?>(value: true, child: Text('Dostupne')),
              DropdownMenuItem<bool?>(value: false, child: Text('Nedostupne')),
            ],
            onChanged: (value) {
              setState(() => _available = value);
              _listKey.currentState?.load(page: 1);
            },
          ),
        ),
      ],
      trailing: [
        FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('Nova knjiga')),
      ],
      columns: const ['', 'Naslov', 'Autori', 'Kategorija', 'Godina', 'Primjerci', 'Ocjena', ''],
      fetch: (page, search) => api.books(
        page: page,
        search: search,
        categoryId: _categoryId,
        available: _available,
        newestFirst: true,
      ),
      rowBuilder: (book, reload) => DataRow(cells: [
        DataCell(ApiImage(url: book.hasCover ? api.bookCoverUrl(book.id) : null)),
        DataCell(SizedBox(width: 220, child: Text(book.title, overflow: TextOverflow.ellipsis))),
        DataCell(SizedBox(width: 180, child: Text(book.authorsText, overflow: TextOverflow.ellipsis))),
        DataCell(Text(book.categoryName)),
        DataCell(Text(book.publishedYear?.toString() ?? '—')),
        DataCell(Text('${book.availableCopies} / ${book.totalCopies}')),
        DataCell(Text(book.averageRating == null ? '—' : book.averageRating!.toStringAsFixed(1).replaceAll('.', ','))),
        DataCell(Row(children: [
          IconButton(tooltip: 'Izmijeni', onPressed: () => _edit(book), icon: const Icon(Icons.edit)),
          IconButton(
            tooltip: book.deleteBlockedReason ?? 'Obriši',
            onPressed: book.deleteBlockedReason != null ? null : () => _delete(book),
            icon: const Icon(Icons.delete_outline),
          ),
        ])),
      ]),
    );
  }
}
