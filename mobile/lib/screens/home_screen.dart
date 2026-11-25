import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/recommendation_tile.dart';
import 'my_library_screen.dart';
import 'recommendations_screen.dart';

/// Početni ekran: sažetak aktivnih posudbi, preporuke s objašnjenjem i obavijesti biblioteke.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _maxLoans = 3;

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
            Text(formatDateTime(item.publishedAt), style: Theme.of(context).textTheme.bodySmall),
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
          _sectionTitle(_loans == null ? 'Moje posudbe' : 'Moje posudbe (${_loans!.length} od $_maxLoans)'),
          ..._loansSection(),
          _sectionTitle('Preporučeno za vas'),
          ..._recommendationSection(),
          _sectionTitle('Obavijesti biblioteke'),
          _newsSection(),
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
      return const Padding(padding: EdgeInsets.all(16), child: Text('Trenutno nema obavijesti.'));
    }

    // Najnovija je prva; dodir otvara puni tekst.
    return Column(children: [
      for (final item in _news!)
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: ListTile(
            key: ValueKey('news-${item.id}'),
            onTap: () => _openNews(item),
            leading: ApiImage(url: _api.newsImageUrl(item.id), width: 72, height: 48, icon: Icons.image),
            title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(formatDateTime(item.publishedAt)),
          ),
        ),
    ]);
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
          leading: ApiImage(url: loan.bookHasCover ? _api.bookCoverUrl(loan.bookId) : null, width: 34, height: 48),
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
