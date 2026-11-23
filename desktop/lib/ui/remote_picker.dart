import 'package:material_ui/material_ui.dart';

/// Polje za odabir jedne stavke pretragom na serveru (član, knjiga, autor...).
class RemotePicker<T extends Object> extends StatelessWidget {
  const RemotePicker({
    super.key,
    required this.label,
    required this.search,
    required this.display,
    required this.onSelected,
    this.hint,
  });

  final String label;
  final String? hint;
  final Future<List<T>> Function(String text) search;
  final String Function(T item) display;
  final void Function(T item) onSelected;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<T>(
      displayStringForOption: display,
      optionsBuilder: (value) async {
        if (value.text.trim().length < 2) {
          return Iterable<T>.empty();
        }
        return search(value.text.trim());
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint ?? 'Upišite najmanje 2 slova',
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.search),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final option in options)
                  ListTile(dense: true, title: Text(display(option)), onTap: () => onSelected(option)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
