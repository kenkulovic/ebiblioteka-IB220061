import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/book_tile.dart';

/// Katalog knjiga: pretraga, filter po kategoriji, samo dostupne; učitavanje dalje pri listanju.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  static const _pageSize = 10;

  final _search = TextEditingController();
  final _scroll = ScrollController();

  final List<BookItem> _books = [];
  List<Lookup> _categories = [];
  int? _categoryId;
  bool? _available;

  int _page = 0;
  int _total = 0;
  bool _loading = false;
  String? _error;

  LibraryApi get _api => context.read<AppState>().api;

  bool get _hasMore => _books.length < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _loadCategories();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final page = await _api.lookups('categories', pageSize: 50);
      if (mounted) setState(() => _categories = page.items);
    } on ApiException {
      // Filter po kategoriji je opcionalan.
    }
  }

  Future<void> _reload() async {
    setState(() {
      _books.clear();
      _page = 0;
      _total = 0;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || (_page > 0 && !_hasMore)) return;

    setState(() => _loading = true);
    try {
      final result = await _api.books(
        page: _page + 1,
        pageSize: _pageSize,
        search: _search.text.trim(),
        categoryId: _categoryId,
        available: _available,
      );
      if (!mounted) return;
      setState(() {
        _books.addAll(result.items);
        _total = result.totalCount;
        _page = result.page;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Katalog')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Naslov ili autor',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _search.clear();
                  _reload();
                },
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _reload(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                key: const ValueKey('catalog-category'),
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kategorija', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sve kategorije')),
                  for (final c in _categories) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) {
                  setState(() => _categoryId = v);
                  _reload();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<bool?>(
                key: const ValueKey('catalog-availability'),
                initialValue: _available,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Dostupnost', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem<bool?>(value: null, child: Text('Sve')),
                  DropdownMenuItem<bool?>(value: true, child: Text('Dostupne')),
                  DropdownMenuItem<bool?>(value: false, child: Text('Nedostupne')),
                ],
                onChanged: (v) {
                  setState(() => _available = v);
                  _reload();
                },
              ),
            ),
          ]),
        ),
        Expanded(child: _content()),
      ]),
    );
  }

  Widget _content() {
    if (_error != null && _books.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _reload, child: const Text('Pokušaj ponovo')),
        ]),
      );
    }

    if (_books.isEmpty && !_loading) {
      return const Center(child: Text('Nema knjiga za zadane uslove.'));
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _books.length + (_loading || _hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _books.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return BookTile(book: _books[index]);
        },
      ),
    );
  }
}
