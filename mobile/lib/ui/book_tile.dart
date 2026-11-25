import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../screens/book_details_screen.dart';
import 'api_image.dart';
import 'dialogs.dart';

/// Stavka liste knjiga (katalog, preporuke, slične knjige). Dodir otvara detalje knjige.
class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, this.footer});

  final BookItem book;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final scheme = Theme.of(context).colorScheme;
    final available = book.availableCopies > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => BookDetailsScreen(bookId: book.id, title: book.title)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ApiImage(url: book.hasCover ? api.bookCoverUrl(book.id) : null, width: 64, height: 92),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(book.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(book.authorsText, style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${book.categoryName}${book.publishedYear == null ? '' : ' · ${book.publishedYear}'}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Row(children: [
                  RatingStars(rating: book.averageRating ?? 0, size: 16),
                  const SizedBox(width: 6),
                  Text(ratingText(book.averageRating), style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: 4),
                Text(
                  available ? 'Dostupno: ${book.availableCopies} od ${book.totalCopies}' : 'Nedostupno',
                  style: TextStyle(color: available ? Colors.green.shade700 : scheme.error, fontSize: 12),
                ),
                if (footer != null) ...[const SizedBox(height: 6), footer!],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
