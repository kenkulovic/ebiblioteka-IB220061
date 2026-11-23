import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

/// Slika s API-ja (naslovnica, slika vijesti, profilna slika). Zahtjev nosi JWT token.
class ApiImage extends StatelessWidget {
  const ApiImage({
    super.key,
    required this.url,
    this.width = 40,
    this.height = 56,
    this.icon = Icons.menu_book,
  });

  final String? url;
  final double width;
  final double height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(icon, size: width * 0.5, color: Theme.of(context).colorScheme.outline),
    );

    if (url == null) {
      return placeholder;
    }

    final headers = context.read<AppState>().api.client.authHeaders;

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        url!,
        headers: headers,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
      ),
    );
  }
}
