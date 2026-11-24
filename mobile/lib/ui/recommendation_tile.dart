import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';

import 'book_tile.dart';

/// Preporučena knjiga s objašnjenjem zašto se preporučuje.
class RecommendationTile extends StatelessWidget {
  const RecommendationTile({super.key, required this.recommendation});

  final Recommendation recommendation;

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
        child: Text(recommendation.explanation, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
