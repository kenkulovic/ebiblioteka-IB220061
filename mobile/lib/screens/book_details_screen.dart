import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/dialogs.dart';
import 'my_library_screen.dart';

/// Detalji knjige (master-detail): opis, dostupnost, rezervacija, ocjene i slične knjige.
class BookDetailsScreen extends StatefulWidget {
  const BookDetailsScreen({super.key, required this.bookId, required this.title});

  final int bookId;
  final String title;

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  BookDetails? _book;
  List<SimilarBook> _similar = [];
  final List<Review> _reviews = [];
  int _reviewTotal = 0;
  int _reviewPage = 0;

  ReserveCheck? _check;
  String? _error;
  bool _reserving = false;
  bool _loadingReviews = false;

  LibraryApi get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final book = await _api.book(widget.bookId);
      if (!mounted) return;
      setState(() {
        _book = book;
        _error = null;
      });
      await Future.wait([_loadCheck(), _loadSimilar(), _loadMoreReviews()]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Može li član rezervisati knjigu; ako ne, razlog se prikazuje uz onemogućeno dugme.
  Future<void> _loadCheck() async {
    try {
      final check = await _api.reserveCheck(widget.bookId);
      if (mounted) setState(() => _check = check);
    } on ApiException {
      // Bez provjere dugme ostaje aktivno, a server svejedno odbija nedozvoljenu rezervaciju.
    }
  }

  Future<void> _loadSimilar() async {
    try {
      final similar = await _api.similarBooks(widget.bookId);
      if (mounted) setState(() => _similar = similar);
    } on ApiException {
      // Slične knjige su dodatak: bez njih ekran radi i dalje.
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_loadingReviews) return;
    setState(() => _loadingReviews = true);

    try {
      final page = await _api.bookReviews(widget.bookId, page: _reviewPage + 1, pageSize: 5);
      if (!mounted) return;
      setState(() {
        _reviews.addAll(page.items);
        _reviewTotal = page.totalCount;
        _reviewPage = page.page;
      });
    } on ApiException {
      // Ocjene su dodatak: bez njih ekran radi i dalje.
    } finally {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _reserve() async {
    final book = _book!;
    final yes = await confirm(
      context,
      title: 'Rezervacija',
      message: book.availableCopies > 0
          ? 'Rezervisati knjigu "${book.title}"?'
          : 'Poslati zahtjev za rezervaciju knjige "${book.title}"?',
      confirmText: 'Pošalji',
    );
    if (!yes || !mounted) return;

    setState(() => _reserving = true);

    final ok = await runAction(
      context,
      () => _api.createReservation(book.id),
      success: book.availableCopies > 0
          ? 'Rezervacija knjige "${book.title}" je poslana. Dobit ćete notifikaciju kad je bibliotekar potvrdi.'
          : 'Zahtjev za knjigu "${book.title}" je poslan. Biće obrađen čim se oslobodi primjerak.',
    );

    if (!mounted) return;
    setState(() => _reserving = false);
    if (ok) context.read<AppState>().refreshUnread();
    await _loadCheck();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Pokušaj ponovo')),
        ]),
      );
    }

    final book = _book;
    if (book == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final scheme = Theme.of(context).colorScheme;
    final available = book.availableCopies > 0;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ApiImage(url: book.hasCover ? _api.bookCoverUrl(book.id) : null, width: 120, height: 172),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(book.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(book.authorsText, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(book.categoryName),
            if (book.publisherName != null) Text('Izdavač: ${book.publisherName}'),
            if (book.publishedYear != null) Text('Godina: ${book.publishedYear}'),
            if (book.pageCount != null) Text('Stranica: ${book.pageCount}'),
            const SizedBox(height: 8),
            Row(children: [
              RatingStars(rating: book.averageRating ?? 0),
              const SizedBox(width: 6),
              Text('${ratingText(book.averageRating)} (${book.reviewCount})'),
            ]),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: available ? Colors.green.shade50 : scheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          available
              ? 'Dostupno primjeraka: ${book.availableCopies} od ${book.totalCopies}'
              : 'Trenutno nema slobodnog primjerka. Možete poslati zahtjev za rezervaciju; bibliotekar ga potvrđuje kad se primjerak vrati.',
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _reserving || _check?.canReserve == false ? null : _reserve,
        icon: const Icon(Icons.bookmark_add),
        label: const Text('Rezerviši knjigu'),
      ),
      if (_check?.canReserve == false && _check?.reason != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_check!.reason!, key: const ValueKey('reserve-reason'), style: TextStyle(color: scheme.error)),
        ),
      // Ograničenje zbog zakasnine vodi direktno na ekran zakasnina.
      if (_check?.canReserve == false && _check?.hasUnpaidFine == true)
        TextButton.icon(
          key: const ValueKey('reserve-my-fines'),
          onPressed: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const MyLibraryScreen(initialTab: 2)),
            );
            await _loadCheck();
          },
          icon: const Icon(Icons.receipt_long),
          label: const Text('Moje zakasnine'),
        ),
      if (book.description != null) ...[
        const SizedBox(height: 20),
        Text('O knjizi', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(book.description!),
      ],
      const SizedBox(height: 20),
      Text('Ocjene ($_reviewTotal)', style: Theme.of(context).textTheme.titleMedium),
      if (_reviews.isEmpty && !_loadingReviews)
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Knjiga još nije ocijenjena.')),
      for (final review in _reviews)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Row(children: [RatingStars(rating: review.rating.toDouble(), size: 16), const SizedBox(width: 8), Text(review.userFullName)]),
          subtitle: Text('${review.comment ?? ''}${review.comment == null ? '' : '\n'}${formatDate(review.createdAt)}'),
        ),
      if (_reviews.length < _reviewTotal)
        TextButton(onPressed: _loadingReviews ? null : _loadMoreReviews, child: const Text('Prikaži još ocjena')),
      if (_similar.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('Slične knjige', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _similar.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final s = _similar[index];
              return InkWell(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(builder: (_) => BookDetailsScreen(bookId: s.book.id, title: s.book.title)),
                ),
                child: SizedBox(
                  width: 110,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ApiImage(url: s.book.hasCover ? _api.bookCoverUrl(s.book.id) : null, width: 110, height: 130),
                    const SizedBox(height: 4),
                    Text(s.book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                    Text('sličnost ${(s.similarity * 100).round()}%',
                        style: Theme.of(context).textTheme.labelSmall),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    ]);
  }
}
