import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/api_image.dart';
import '../ui/dialogs.dart';

/// Profil člana: podaci, profilna slika, promjena lozinke i odjava.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();

  Member? _me;
  List<City> _cities = [];
  int? _cityId;
  int _imageVersion = 0;
  String? _error;
  bool _saving = false;

  LibraryApi get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _currentPassword, _newPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await _api.me();
      final cities = await _api.cities(pageSize: 50);
      if (!mounted) return;
      setState(() {
        _me = me;
        _cities = cities.items;
        _firstName.text = me.firstName;
        _lastName.text = me.lastName;
        _email.text = me.email;
        _cityId = me.cityId;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () async => _me = await _api.updateMe(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        cityId: _cityId!,
      ),
      success: 'Podaci su sačuvani.',
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) await _load();
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordKey.currentState!.validate()) return;

    final ok = await runAction(
      context,
      () => _api.changePassword(_currentPassword.text, _newPassword.text),
      success: 'Lozinka je promijenjena.',
    );
    if (ok) {
      _currentPassword.clear();
      _newPassword.clear();
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final ok = await runAction(context, () => _api.setMyImage(picked.name, bytes), success: 'Slika je promijenjena.');
    if (ok) await _afterImageChange();
  }

  Future<void> _removeImage() async {
    final ok = await runAction(context, _api.removeMyImage, success: 'Slika je uklonjena.');
    if (ok) await _afterImageChange();
  }

  Future<void> _afterImageChange() async {
    _imageVersion++;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: me == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Center(
                child: Column(children: [
                  ClipOval(
                    child: ApiImage(
                      // Verzija u adresi sprečava prikaz stare slike iz keša nakon promjene.
                      url: me.hasProfileImage ? '${_api.memberImageUrl(me.id)}?v=$_imageVersion' : null,
                      width: 110,
                      height: 110,
                      icon: Icons.person,
                      radius: 55,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(me.fullName, style: Theme.of(context).textTheme.titleLarge),
                  Text('Član broj ${me.membershipNumber}'),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo), label: const Text('Promijeni sliku')),
                    if (me.hasProfileImage) TextButton(onPressed: _removeImage, child: const Text('Ukloni')),
                  ]),
                ]),
              ),
              const Divider(),
              Text('Moji podaci', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Form(
                key: _profileKey,
                child: Column(children: [
                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'Ime', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Unesite ime.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Prezime', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Unesite prezime.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                    validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                        ? 'Unesite ispravnu e-mail adresu.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _cityId,
                    decoration: const InputDecoration(labelText: 'Grad', border: OutlineInputBorder()),
                    items: [for (final c in _cities) DropdownMenuItem(value: c.id, child: Text(c.name))],
                    onChanged: (v) => setState(() => _cityId = v),
                    validator: (v) => v == null ? 'Odaberite grad.' : null,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: _saving ? null : _saveProfile, child: const Text('Sačuvaj podatke')),
                  ),
                ]),
              ),
              const Divider(height: 32),
              ExpansionTile(
                title: const Text('Promjena lozinke'),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  Form(
                    key: _passwordKey,
                    child: Column(children: [
                      TextFormField(
                        controller: _currentPassword,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Trenutna lozinka', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? 'Unesite trenutnu lozinku.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPassword,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Nova lozinka', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.length < 4) ? 'Najmanje 4 znaka.' : null,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(onPressed: _changePassword, child: const Text('Promijeni lozinku')),
                      ),
                    ]),
                  ),
                ],
              ),
              const Divider(height: 32),
              OutlinedButton.icon(
                onPressed: context.read<AppState>().logout,
                icon: const Icon(Icons.logout),
                label: const Text('Odjava'),
              ),
            ]),
    );
  }
}
