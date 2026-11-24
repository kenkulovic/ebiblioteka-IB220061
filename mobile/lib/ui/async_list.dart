import 'dart:async';

import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';

/// Lista koja se učitava s servera, uz osvježavanje povlačenjem i prikaz greške/praznog stanja.
class AsyncList<T> extends StatefulWidget {
  const AsyncList({
    super.key,
    required this.load,
    required this.itemBuilder,
    this.header,
    this.emptyText = 'Nema podataka.',
  });

  final Future<List<T>> Function() load;
  final Widget Function(BuildContext context, T item, Future<void> Function() reload) itemBuilder;

  /// Prikazuje se iznad stavki kad ih ima (npr. objašnjenje ili upozorenje).
  final Widget Function(List<T> items)? header;
  final String emptyText;

  @override
  State<AsyncList<T>> createState() => AsyncListState<T>();
}

class AsyncListState<T> extends State<AsyncList<T>> {
  /// Lista se sama osvježava, pa član vidi promjene koje bibliotekar napravi bez ručnog osvježavanja.
  static const _autoRefresh = Duration(seconds: 20);

  List<T>? _items;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    reload();
    _timer = Timer.periodic(_autoRefresh, (_) => reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final items = await widget.load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: reload, child: const Text('Pokušaj ponovo')),
          ]),
        ),
      );
    }

    final items = _items!;

    return RefreshIndicator(
      onRefresh: reload,
      child: items.isEmpty
          ? ListView(children: [
              const SizedBox(height: 120),
              Center(child: Text(widget.emptyText)),
            ])
          : ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (widget.header != null) widget.header!(items),
                for (final item in items) widget.itemBuilder(context, item, reload),
              ],
            ),
    );
  }
}
