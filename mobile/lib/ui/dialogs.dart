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

/// Izvrši radnju; greška API-ja se prikaže korisniku. Vraća true ako je radnja uspjela.
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

/// Zvjezdice za prikaz ocjene (samo čitanje) ili odabir (kad je [onChanged] zadan).
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.onChanged, this.size = 18});

  final double rating;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(i),
          child: Icon(
            rating >= i ? Icons.star : (rating >= i - 0.5 ? Icons.star_half : Icons.star_border),
            color: Colors.amber.shade700,
            size: size,
          ),
        ),
    ]);
  }
}

String ratingText(double? rating) => rating == null ? 'Bez ocjena' : rating.toStringAsFixed(1).replaceAll('.', ',');

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
