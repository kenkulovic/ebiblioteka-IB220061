import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

/// Slika s API-ja (naslovnica, slika vijesti, profilna slika). Zahtjev nosi JWT token.
class ApiImage extends StatelessWidget {
  const ApiImage({
    super.key,
    required this.url,
    this.width = 56,
    this.height = 80,
    this.icon = Icons.menu_book,
    this.fit = BoxFit.cover,
    this.radius = 6,
  });

  final String? url;
  final double width;
  final double height;
  final IconData icon;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(radius)),
      child: Icon(icon, size: (width < height ? width : height) * 0.45, color: scheme.outline),
    );

    if (url == null) {
      return placeholder;
    }

    final headers = context.read<AppState>().api.client.authHeaders;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url!,
        headers: headers,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
      ),
    );
  }
}
