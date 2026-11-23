import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';

/// Tabela sa pretragom i straničenjem. Podatke dohvaća [fetch] (strana, tekst pretrage).
/// Kad se promijeni filter, roditelj mijenja `key` pa se tabela ponovo učitava od prve strane.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.fetch,
    required this.columns,
    required this.rowBuilder,
    this.searchHint,
    this.leading = const [],
    this.trailing = const [],
    this.emptyText = 'Nema podataka.',
  });

  final Future<PagedResult<T>> Function(int page, String search) fetch;
  final List<String> columns;
  final DataRow Function(T item, VoidCallback reload) rowBuilder;

  /// Ako je null, polje za pretragu se ne prikazuje.
  final String? searchHint;

  /// Dodatni elementi ispred polja za pretragu (npr. filteri) i iza njega (npr. dugme "Dodaj").
  final List<Widget> leading;
  final List<Widget> trailing;
  final String emptyText;

  @override
  State<PagedListView<T>> createState() => PagedListViewState<T>();
}

class PagedListViewState<T> extends State<PagedListView<T>> {
  final _search = TextEditingController();

  PagedResult<T>? _result;
  String? _error;
  bool _loading = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void reload() => load();

  Future<void> load({int? page}) async {
    final target = page ?? _page;
    setState(() => _loading = true);

    try {
      final result = await widget.fetch(target, _search.text.trim());

      // Obrisan je zadnji zapis na zadnjoj strani: vrati se jednu stranicu nazad.
      if (result.items.isEmpty && target > 1) {
        await load(page: target - 1);
        return;
      }

      if (!mounted) return;
      setState(() {
        _result = result;
        _page = target;
        _error = null;
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

  @override
  Widget build(BuildContext context) {
    final hasToolbar = widget.searchHint != null || widget.leading.isNotEmpty || widget.trailing.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasToolbar)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: Row(
              children: [
                ...widget.leading.expand((w) => [w, const SizedBox(width: 12)]),
                if (widget.searchHint != null) ...[
                  SizedBox(
                    width: 320,
                    child: TextField(
                      key: const ValueKey('list-search'),
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => load(page: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(onPressed: () => load(page: 1), child: const Text('Traži')),
                ],
                const Spacer(),
                ...widget.trailing,
              ],
            ),
          ),
        Expanded(child: _buildContent(context)),
        _buildPager(),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: load, child: const Text('Pokušaj ponovo')),
          ],
        ),
      );
    }

    final items = _result!.items;
    if (items.isEmpty) {
      return Center(child: Text(widget.emptyText));
    }

    return Stack(
      children: [
        SingleChildScrollView(
          child: SizedBox(
            width: double.infinity,
            child: DataTable(
              columns: [for (final c in widget.columns) DataColumn(label: Text(c))],
              rows: [for (final item in items) widget.rowBuilder(item, reload)],
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              headingRowColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHighest),
            ),
          ),
        ),
        if (_loading) const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator()),
      ],
    );
  }

  Widget _buildPager() {
    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Ukupno: ${result.totalCount}'),
          const SizedBox(width: 16),
          IconButton(
            tooltip: 'Prethodna strana',
            onPressed: _page > 1 && !_loading ? () => load(page: _page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Strana $_page / ${result.totalPages}'),
          IconButton(
            tooltip: 'Sljedeća strana',
            onPressed: _page < result.totalPages && !_loading ? () => load(page: _page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
