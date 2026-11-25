import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'dialogs.dart';

/// Brzo dodavanje kategorije iz forme knjige: vraća novu kategoriju ili null ako je dijalog zatvoren.
class QuickAddCategoryDialog extends StatefulWidget {
  const QuickAddCategoryDialog({super.key});

  @override
  State<QuickAddCategoryDialog> createState() => _QuickAddCategoryDialogState();
}

class _QuickAddCategoryDialogState extends State<QuickAddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final created = await context.read<AppState>().api.createLookup('categories', _name.text.trim());
      if (mounted) {
        showMessage(context, 'Kategorija "${created.name}" je dodana.');
        Navigator.pop(context, created);
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
      title: const DialogTitle('Nova kategorija'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              key: const ValueKey('quick-category-name'),
              controller: _name,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Naziv *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Naziv je obavezan.' : null,
              onFieldSubmitted: (_) => _saving ? null : _save(),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Otkaži')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Sačuvaj')),
      ],
    );
  }
}

/// Brzo dodavanje izdavača iz forme knjige: vraća novog izdavača ili null ako je dijalog zatvoren.
class QuickAddPublisherDialog extends StatefulWidget {
  const QuickAddPublisherDialog({super.key});

  @override
  State<QuickAddPublisherDialog> createState() => _QuickAddPublisherDialogState();
}

class _QuickAddPublisherDialogState extends State<QuickAddPublisherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  List<City> _cities = [];
  int? _cityId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final page = await context.read<AppState>().api.cities(pageSize: 50);
      if (mounted) {
        setState(() {
          _cities = page.items;
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
      final created = await context.read<AppState>().api.createPublisher(_name.text.trim(), _cityId!);
      if (mounted) {
        showMessage(context, 'Izdavač "${created.name}" je dodan.');
        Navigator.pop(context, created);
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
      title: const DialogTitle('Novi izdavač'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    key: const ValueKey('quick-publisher-name'),
                    controller: _name,
                    autofocus: true,
                    maxLength: 150,
                    decoration: const InputDecoration(labelText: 'Naziv *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Naziv je obavezan.' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('quick-publisher-city'),
                    initialValue: _cityId,
                    decoration: const InputDecoration(labelText: 'Grad *', border: OutlineInputBorder()),
                    items: [for (final c in _cities) DropdownMenuItem(value: c.id, child: Text(c.name))],
                    onChanged: (v) => setState(() => _cityId = v),
                    validator: (v) => v == null ? 'Odaberite grad.' : null,
                  ),
                  if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ]),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Otkaži')),
        FilledButton(onPressed: _saving || _loading ? null : _save, child: const Text('Sačuvaj')),
      ],
    );
  }
}
