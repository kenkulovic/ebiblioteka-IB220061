import 'dart:typed_data';

import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/dialogs.dart';
import '../ui/paged_list_view.dart';

/// Vijesti koje članovi vide na početnom ekranu mobilne aplikacije.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _listKey = GlobalKey<PagedListViewState<NewsItem>>();

  Future<void> _edit(NewsItem? item) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _NewsDialog(item: item));
    if (saved == true) _listKey.currentState?.load(page: item == null ? 1 : null);
  }

  Future<void> _delete(NewsItem item) async {
    final ok = await confirm(
      context,
      title: 'Brisanje vijesti',
      message: 'Obrisati vijest "${item.title}"?',
      confirmText: 'Obriši',
    );
    if (!ok || !mounted) return;

    final api = context.read<AppState>().api;
    final done = await runAction(context, () => api.deleteNews(item.id), success: 'Vijest je obrisana.');
    if (done) _listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;

    return PagedListView<NewsItem>(
      key: _listKey,
      searchHint: 'Naslov ili tekst',
      trailing: [
        FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('Nova vijest')),
      ],
      columns: const ['', 'Naslov', 'Tekst', 'Objavljeno', ''],
      fetch: (page, search) => api.news(page: page, search: search),
      rowBuilder: (item, reload) => DataRow(cells: [
        DataCell(ApiImage(url: api.newsImageUrl(item.id), width: 84, height: 42, icon: Icons.image)),
        DataCell(SizedBox(width: 200, child: Text(item.title, overflow: TextOverflow.ellipsis))),
        DataCell(SizedBox(width: 380, child: Text(item.text, maxLines: 2, overflow: TextOverflow.ellipsis))),
        DataCell(Text(formatDateTime(item.publishedAt))),
        DataCell(Row(children: [
          IconButton(tooltip: 'Izmijeni', onPressed: () => _edit(item), icon: const Icon(Icons.edit)),
          IconButton(tooltip: 'Obriši', onPressed: () => _delete(item), icon: const Icon(Icons.delete_outline)),
        ])),
      ]),
    );
  }
}

class _NewsDialog extends StatefulWidget {
  const _NewsDialog({this.item});

  final NewsItem? item;

  @override
  State<_NewsDialog> createState() => _NewsDialogState();
}

class _NewsDialogState extends State<_NewsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.item?.title);
  late final _text = TextEditingController(text: widget.item?.text);

  Uint8List? _image;
  String _imageName = 'vijest.png';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _image = bytes;
      _imageName = file.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final creating = widget.item == null;
    if (creating && _image == null) {
      setState(() => _error = 'Slika vijesti je obavezna.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = context.read<AppState>().api;
    try {
      if (creating) {
        await api.createNews(_title.text.trim(), _text.text.trim(), _imageName, _image!);
      } else {
        await api.updateNews(widget.item!.id, _title.text.trim(), _text.text.trim(),
            imageName: _imageName, imageBytes: _image);
      }
      if (mounted) {
        showMessage(context, 'Vijest "${_title.text.trim()}" je ${creating ? 'objavljena' : 'sačuvana'}.');
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
    final api = context.read<AppState>().api;

    return AlertDialog(
      title: DialogTitle(widget.item == null ? 'Nova vijest' : 'Izmjena vijesti'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_image != null)
                Image.memory(_image!, height: 140, fit: BoxFit.cover)
              else if (widget.item != null)
                ApiImage(url: api.newsImageUrl(widget.item!.id), width: 280, height: 140, icon: Icons.image),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: Text(widget.item == null ? 'Odaberi sliku *' : 'Promijeni sliku'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Naslov *', border: OutlineInputBorder()),
                maxLength: 100,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Naslov je obavezan.' : null,
              ),
              TextFormField(
                controller: _text,
                decoration: const InputDecoration(labelText: 'Tekst *', border: OutlineInputBorder()),
                maxLines: 5,
                maxLength: 2000,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Tekst je obavezan.' : null,
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Otkaži')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Sačuvaj')),
      ],
    );
  }
}
