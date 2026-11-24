import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';

void showMessage(BuildContext context, String text, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? scheme.error : null,
      duration: Duration(seconds: error ? 6 : 3),
    ));
}

/// Izvrsi radnju; greska API-ja se prikaze korisniku. Vraca true ako je radnja uspjela.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) {
      showMessage(context, success);
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) {
      showMessage(context, e.message, error: true);
    }
    return false;
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Potvrdi',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: DialogTitle(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Otkaži')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText)),
      ],
    ),
  );
  return result ?? false;
}

/// Trazi od korisnika razlog (npr. za otkazivanje ili povrat). Vraca null ako odustane.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String hint,
  required int minLength,
  String confirmText = 'Potvrdi',
  String? description,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ReasonDialog(
      title: title,
      hint: hint,
      minLength: minLength,
      confirmText: confirmText,
      description: description,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.minLength,
    required this.confirmText,
    this.description,
  });

  final String title;
  final String hint;
  final int minLength;
  final String confirmText;
  final String? description;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _length => _controller.text.trim().length;

  @override
  Widget build(BuildContext context) {
    final valid = _length >= widget.minLength;

    return AlertDialog(
      title: DialogTitle(widget.title),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.description != null) ...[
              Text(widget.description!),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: widget.hint,
                border: const OutlineInputBorder(),
                helperText: 'Uneseno: $_length znakova (najmanje ${widget.minLength})',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, _controller.text.trim()) : null,
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

/// Naslov dijaloga s dugmetom "X" za zatvaranje (zatvara dijalog bez promjene).
class DialogTitle extends StatelessWidget {
  const DialogTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text)),
        IconButton(
          key: const ValueKey('dialog-close'),
          tooltip: 'Zatvori',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.maybePop(context),
        ),
      ],
    );
  }
}
