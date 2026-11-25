import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_state.dart';
import '../ui/dialogs.dart';

enum _Stage { starting, approving, capturing, success, failed }

/// Plaćanje zakasnine u aplikaciji: PayPal stranica se otvara unutar aplikacije (WebView),
/// bez izlaska u vanjski preglednik. Iznos određuje server; uplatu potvrđuje server (capture).
class PayPalScreen extends StatefulWidget {
  const PayPalScreen({super.key, required this.fine});

  final Fine fine;

  /// Potvrda prije plaćanja, zatim ekran plaćanja. Vraća true ako je zakasnina plaćena.
  static Future<bool> pay(BuildContext context, Fine fine) async {
    final yes = await confirm(
      context,
      title: 'Plaćanje zakasnine',
      message: 'Platiti zakasninu od ${formatKm(fine.amount)} (${formatEur(fine.amountEur)}) putem PayPal-a?',
      confirmText: 'Nastavi na PayPal',
    );
    if (!yes || !context.mounted) return false;

    final paid = await Navigator.push<bool>(context, MaterialPageRoute<bool>(builder: (_) => PayPalScreen(fine: fine)));
    return paid == true;
  }

  @override
  State<PayPalScreen> createState() => _PayPalScreenState();
}

class _PayPalScreenState extends State<PayPalScreen> {
  _Stage _stage = _Stage.starting;
  PaymentInit? _payment;
  WebViewController? _web;
  String? _error;

  LibraryApi get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.starting;
      _error = null;
    });

    try {
      final payment = await _api.startPayPalPayment(widget.fine.id);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (request) {
            // Povratak sa PayPal-a: stranica se ne otvara, nego aplikacija sama nastavlja.
            if (request.url.startsWith(payment.returnUrl)) {
              _onApproved();
              return NavigationDecision.prevent;
            }
            if (request.url.startsWith(payment.cancelUrl)) {
              _onCancelled();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ))
        ..loadRequest(Uri.parse(payment.approvalUrl));

      if (!mounted) return;
      setState(() {
        _payment = payment;
        _web = controller;
        _stage = _Stage.approving;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _stage = _Stage.failed;
        });
      }
    }
  }

  /// Član je odobrio uplatu u PayPal-u: server je potvrđuje (capture); aplikacija sama ništa ne bilježi.
  Future<void> _onApproved() async {
    if (_stage == _Stage.capturing) return;
    setState(() => _stage = _Stage.capturing);

    try {
      await _api.capturePayment(_payment!.paymentId);
      if (mounted) setState(() => _stage = _Stage.success);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _stage = _Stage.failed;
        });
      }
    }
  }

  Future<void> _onCancelled() async {
    await _closePending();
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _closePending() async {
    final payment = _payment;
    if (payment == null || _stage == _Stage.success) return;

    try {
      await _api.cancelPayment(payment.paymentId);
    } on ApiException {
      // Ako se plaćanje ne može otkazati (već zatvoreno), nema šta više da se uradi.
    }
  }

  Future<void> _back() async {
    if (_stage == _Stage.success) {
      Navigator.pop(context, true);
      return;
    }
    if (_stage == _Stage.capturing) return;

    if (_stage == _Stage.approving) {
      final leave = await confirm(
        context,
        title: 'Odustajanje od plaćanja',
        message: 'Prekinuti plaćanje zakasnine?',
        confirmText: 'Prekini',
      );
      if (!leave || !mounted) return;
      await _closePending();
    }

    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Plaćanje zakasnine'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
          actions: [
            if (_stage == _Stage.starting || _stage == _Stage.approving)
              TextButton(onPressed: _back, child: const Text('Odustani')),
          ],
        ),
        body: _content(),
      ),
    );
  }

  Widget _content() {
    switch (_stage) {
      case _Stage.starting:
        return const Center(child: CircularProgressIndicator());

      case _Stage.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 56, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(_error ?? 'Plaćanje nije uspjelo.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _start, child: const Text('Pokušaj ponovo')),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Odustani')),
            ]),
          ),
        );

      case _Stage.capturing:
        return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Potvrđujem uplatu...'),
          ]),
        );

      case _Stage.success:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, size: 72, color: Colors.green.shade700),
              const SizedBox(height: 12),
              Text('Plaćanje je uspješno', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Zakasnina ${formatKm(widget.fine.amount)} je plaćena. Ograničenje na vašem računu je uklonjeno.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gotovo')),
            ]),
          ),
        );

      case _Stage.approving:
        final payment = _payment!;
        return Column(children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.fine.bookTitle, style: Theme.of(context).textTheme.titleSmall),
              Text('Iznos: ${formatKm(payment.amountKm)}', style: Theme.of(context).textTheme.titleMedium),
              Text(
                'Naplata u EUR po kursu ${payment.exchangeRate.toString().replaceAll('.', ',')}: '
                '${formatEur(payment.amountEur)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text('Iznos određuje server.', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          Expanded(child: WebViewWidget(controller: _web!)),
        ]);
    }
  }
}
