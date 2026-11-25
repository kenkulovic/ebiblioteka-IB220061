import 'package:material_ui/material_ui.dart';

import 'dialogs.dart';

/// Ocjena 1-5 i neobavezan komentar: za novu ocjenu ili izmjenu postojeće ([editing]).
/// Vraća (ocjena, komentar) ili null ako je dijalog zatvoren.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    required this.title,
    this.initialRating = 0,
    this.initialComment,
    this.editing = false,
  });

  final String title;
  final int initialRating;
  final String? initialComment;
  final bool editing;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late final _comment = TextEditingController(text: widget.initialComment);
  late int _rating = widget.initialRating;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    if (_rating == 0) {
      setState(() => _error = 'Odaberite ocjenu od 1 do 5 zvjezdica.');
      return;
    }
    final text = _comment.text.trim();
    Navigator.pop(context, (_rating, text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: DialogTitle('${widget.editing ? 'Izmijenite ocjenu' : 'Ocijenite'}: ${widget.title}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        RatingStars(
          rating: _rating.toDouble(),
          size: 36,
          onChanged: (v) => setState(() {
            _rating = v;
            _error = null;
          }),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _comment,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Komentar (nije obavezan)', border: OutlineInputBorder()),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
        FilledButton(onPressed: _submit, child: Text(widget.editing ? 'Sačuvaj' : 'Pošalji')),
      ],
    );
  }
}
