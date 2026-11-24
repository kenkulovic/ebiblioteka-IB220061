import 'dart:async';

import 'package:ebiblioteka_api/ebiblioteka_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/dialogs.dart';

/// Obavijesti se same osvježavaju (svakih 15 sekundi), bez ručnog osvježavanja.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _refreshInterval = Duration(seconds: 15);

  List<AppNotification>? _items;
  String? _error;
  Timer? _timer;

  LibraryApi get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_refreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final page = await _api.notifications(pageSize: 50);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && _items == null) setState(() => _error = e.message);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      await _api.markNotificationRead(n.id);
      if (!mounted) return;
      context.read<AppState>().refreshUnread();
      await _load();
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: DialogTitle(n.title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.text),
          const SizedBox(height: 12),
          Text(formatDateTime(n.createdAt), style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvori'))],
      ),
    );
  }

  Future<void> _markAll() async {
    if (await runAction(context, _api.markAllNotificationsRead)) {
      if (!mounted) return;
      context.read<AppState>().refreshUnread();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items?.any((n) => !n.isRead) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obavijesti'),
        actions: [
          if (hasUnread) TextButton(onPressed: _markAll, child: const Text('Označi sve')),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_items == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items == null) {
      return Center(child: Text(_error!));
    }
    if (_items!.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [SizedBox(height: 120), Center(child: Text('Nemate obavijesti.'))]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _items!.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final n = _items![index];
          return ListTile(
            leading: Icon(n.isRead ? Icons.notifications_none : Icons.notifications_active,
                color: n.isRead ? null : Theme.of(context).colorScheme.primary),
            title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
            subtitle: Text(n.text, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Text(formatDate(n.createdAt), style: Theme.of(context).textTheme.bodySmall),
            onTap: () => _open(n),
          );
        },
      ),
    );
  }
}
