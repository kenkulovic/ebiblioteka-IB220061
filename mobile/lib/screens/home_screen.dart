import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/recommendation_tile.dart';
import 'my_library_screen.dart';
import 'recommendations_screen.dart';

/// Početni ekran: vijesti biblioteke i preporuke knjiga s objašnjenjem.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NewsItem>? _news;
  List<Loan>? _loans;
  List<Recommendation>? _recommendations;
  String? _newsError;
  String? _recommendationsError;

  LibraryApi get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadNews(), _loadLoans(), _loadRecommendations()]);
  }

  Future<void> _loadNews() async {
    try {
      final page = await _api.news(pageSize: 5);
      if (mounted) {
        setState(() {
          _news = page.items;
          _newsError = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _newsError = e.message);
    }
  }

  Future<void> _loadLoans() async {
    try {
      final page = await _api.myLoans(pageSize: 10, filter: 'Active');
      if (mounted) setState(() => _loans = page.items);
    } on ApiException {
      // Sažetak posudbi je dodatak: bez njega početni ekran radi i dalje.
    }
  }

  void _openLibrary(int tab) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MyLibraryScreen(initialTab: tab)));

  Future<void> _loadRecommendations() async {
    try {
      final items = await _api.recommendations(count: 3);
      if (mounted) {
        setState(() {
          _recommendations = items;
          _recommendationsError = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _recommendationsError = e.message);
    }
  }

  void _openNews(NewsItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ApiImage(
              url: _api.newsImageUrl(item.id),
              width: double.infinity,
              height: 180,
              icon: Icons.image,
            ),
            const SizedBox(height: 12),
            Text(item.title, style: Theme.of(context).textTheme.titleLarge),
            Text(formatDate(item.publishedAt), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Text(item.text),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppState>().user!;

    return Scaffold(
      appBar: AppBar(title: Text('Dobrodošli, ${user.firstName}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          _sectionTitle('Vijesti'),
          _newsSection(),
          _sectionTitle('Moje posudbe'),
          ..._loansSection(),
          _sectionTitle('Preporučeno za vas'),
          ..._recommendationSection(),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );

  Widget _newsSection() {
    if (_newsError != null) {
      return Padding(padding: const EdgeInsets.all(16), child: Text(_newsError!));
    }
    if (_news == null) {
      return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
    }
    if (_news!.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('Trenutno nema vijesti.'));
    }

    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _news!.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _news![index];
          return SizedBox(
            width: 270,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openNews(item),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ApiImage(
                    url: _api.newsImageUrl(item.id),
                    width: 270,
                    height: 110,
                    radius: 0,
                    icon: Icons.image,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.title,
                          style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(item.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _loansSection() {
    final scheme = Theme.of(context).colorScheme;
    final loans = _loans;
    if (loans == null) return const [SizedBox(height: 40)];

    // Rok koji ističe u naredna 2 dana (ili je prošao) je istaknut.
    final soon = DateTime.now().add(const Duration(days: 2));

    return [
      if (loans.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Trenutno nemate aktivnih posudbi.')),
      for (final loan in loans)
        ListTile(
          dense: true,
          leading: const Icon(Icons.menu_book),
          title: Text(loan.bookTitle),
          trailing: Text(
            'Rok: ${formatDate(loan.dueDate)}',
            style: loan.dueDate.isBefore(soon)
                ? TextStyle(color: scheme.error, fontWeight: FontWeight.bold)
                : null,
          ),
        ),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(onPressed: () => _openLibrary(0), child: const Text('Sve posudbe')),
        TextButton(onPressed: () => _openLibrary(1), child: const Text('Rezervacije')),
      ]),
    ];
  }

  List<Widget> _recommendationSection() {
    if (_recommendationsError != null) {
      return [Padding(padding: const EdgeInsets.all(16), child: Text(_recommendationsError!))];
    }
    if (_recommendations == null) {
      return const [SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))];
    }
    if (_recommendations!.isEmpty) {
      return const [Padding(padding: EdgeInsets.all(16), child: Text('Za sada nema preporuka.'))];
    }

    return [
      for (final r in _recommendations!) RecommendationTile(recommendation: r),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const RecommendationsScreen()),
          ),
          child: const Text('Prikaži sve'),
        ),
      ),
    ];
  }
}
