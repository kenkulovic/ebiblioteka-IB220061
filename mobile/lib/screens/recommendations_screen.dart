import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/async_list.dart';
import '../ui/recommendation_tile.dart';

/// "Preporučeno za vas": do 5 knjiga, svaka s objašnjenjem zašto se preporučuje.
class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;

    return Scaffold(
      appBar: AppBar(title: const Text('Preporučeno za vas')),
      body: AsyncList<Recommendation>(
        emptyText: 'Za sada nema preporuka.',
        load: () => api.recommendations(count: 5),
        itemBuilder: (context, recommendation, reload) =>
            RecommendationTile(recommendation: recommendation, showDetailsButton: true),
      ),
    );
  }
}
