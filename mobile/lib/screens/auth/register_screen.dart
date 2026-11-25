import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../ui/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _userName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  List<City> _cities = [];
  int? _cityId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _userName, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final cities = await context.read<AppState>().api.registrationCities();
      if (mounted) setState(() => _cities = cities);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await context.read<AppState>().register(
            userName: _userName.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            cityId: _cityId!,
            phoneNumber: _phone.text.trim(),
          );
      // Uspješna registracija je i prijava: početni ekran se prikazuje automatski.
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
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
      appBar: AppBar(title: const Text('Registracija')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _firstName,
                decoration: const InputDecoration(labelText: 'Ime', border: OutlineInputBorder()),
                validator: (v) => validateName(v, 'ime'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastName,
                decoration: const InputDecoration(labelText: 'Prezime', border: OutlineInputBorder()),
                validator: (v) => validateName(v, 'prezime'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _cityId,
                decoration: const InputDecoration(labelText: 'Grad', border: OutlineInputBorder()),
                items: [for (final c in _cities) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => setState(() => _cityId = v),
                validator: (v) => v == null ? 'Odaberite grad.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _userName,
                decoration: const InputDecoration(labelText: 'Korisničko ime', border: OutlineInputBorder()),
                validator: validateUserName,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon (nije obavezno)', border: OutlineInputBorder()),
                validator: validatePhone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Lozinka', border: OutlineInputBorder()),
                validator: validateNewPassword,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Ponovite lozinku', border: OutlineInputBorder()),
                validator: (v) => validateRepeatedPassword(v, _password.text),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Registruj se'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
