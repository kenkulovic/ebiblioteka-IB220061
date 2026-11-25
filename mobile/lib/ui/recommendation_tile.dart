import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';

import '../screens/book_details_screen.dart';
import 'book_tile.dart';

/// Preporučena knjiga s objašnjenjem zašto se preporučuje.
class RecommendationTile extends StatelessWidget {
  const RecommendationTile({super.key, required this.recommendation, this.showDetailsButton = false});

  final Recommendation recommendation;

  /// Ekran "Preporučeno za vas" ima i izričito dugme "Detalji"; na početnom je dovoljan dodir na karticu.
  final bool showDetailsButton;

  @override
  Widget build(BuildContext context) {
    return BookTile(
      book: recommendation.book,
      footer: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(recommendation.explanation, style: Theme.of(context).textTheme.bodySmall),
          if (showDetailsButton)
            Align(
              alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey('recommendation-details-${recommendation.book.id}'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BookDetailsScreen(bookId: recommendation.book.id, title: recommendation.book.title),
                ),
              ),
              child: const Text('Detalji'),
            ),
          ),
        ]),
      ),
    );
  }
}
