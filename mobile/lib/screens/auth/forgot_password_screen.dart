import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../ui/dialogs.dart';

/// Reset lozinke u dva koraka: 1) e-mail, 2) kod iz e-maila i nova lozinka.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  LibraryApi get _api => context.read<AppState>().api;

  Future<void> _sendCode() async {
    if (!_emailKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _api.forgotPassword(_email.text.trim());
      if (mounted) setState(() => _codeSent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _api.resetPassword(_email.text.trim(), _code.text.trim(), _password.text);
      if (!mounted) return;
      showMessage(context, 'Lozinka je promijenjena. Prijavite se novom lozinkom.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Zaboravljena lozinka')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!_codeSent)
              Form(
                key: _emailKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Unesite e-mail adresu računa. Poslat ćemo vam kod za promjenu lozinke.'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Unesite ispravnu e-mail adresu.' : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _sendCode,
                    child: const Text('Pošalji kod'),
                  ),
                ]),
              )
            else
              Form(
                key: _resetKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Ako račun s adresom ${_email.text.trim()} postoji, kod je poslan. '
                      'Kod važi nekoliko minuta.'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kod iz e-maila', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Unesite kod.' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nova lozinka', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.length < 4) ? 'Najmanje 4 znaka.' : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _reset, child: const Text('Promijeni lozinku')),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _codeSent = false),
                    child: const Text('Pošalji kod ponovo'),
                  ),
                ]),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ]),
        ),
      ),
    );
  }
}
