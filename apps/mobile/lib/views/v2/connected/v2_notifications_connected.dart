import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/notification_repository.dart';
import '../../../viewmodels/session_viewmodel.dart';
import '../pages/v2_notifications_page.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';

/// Halaman Notifikasi (frame 2.4) yang terhubung ke `GET /api/v1/notifications`
/// dan `POST /api/v1/notifications/read-all`.
class V2NotificationsConnectedPage extends ConsumerStatefulWidget {
  const V2NotificationsConnectedPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'v2-notifikasi'),
    builder: (_) => const V2NotificationsConnectedPage(),
  );

  @override
  ConsumerState<V2NotificationsConnectedPage> createState() =>
      _V2NotificationsConnectedPageState();
}

class _V2NotificationsConnectedPageState
    extends ConsumerState<V2NotificationsConnectedPage> {
  bool _loading = true;
  String? _error;
  List<NotificationRecord> _items = const <NotificationRecord>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(notificationRepositoryProvider)
          .fetchNotifications();
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = serviceError(error);
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua notifikasi ditandai sudah dibaca.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(serviceError(error))));
    }
  }

  V2IconName _iconFor(String category) => switch (category) {
    'inventory' => V2IconName.box,
    'harvest' => V2IconName.layers,
    'weather' => V2IconName.cloud,
    _ => V2IconName.sprout,
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Theme(
        data: V2Theme.light,
        child: Scaffold(
          backgroundColor: V2Colors.canvas,
          body: SafeArea(
            child: Column(
              children: [
                V2AppBar(
                  title: 'Notifikasi',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Theme(
        data: V2Theme.light,
        child: Scaffold(
          backgroundColor: V2Colors.canvas,
          body: SafeArea(
            child: Column(
              children: [
                V2AppBar(
                  title: 'Notifikasi',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(V2Space.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Gagal memuat notifikasi', style: V2Type.h2),
                        const SizedBox(height: V2Space.sm),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: V2Type.body.copyWith(color: V2Colors.muted),
                        ),
                        const SizedBox(height: V2Space.xl),
                        V2Button(label: 'Coba lagi', onPressed: _load),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Theme(
        data: V2Theme.light,
        child: Scaffold(
          backgroundColor: V2Colors.canvas,
          body: SafeArea(
            child: Column(
              children: [
                V2AppBar(
                  title: 'Notifikasi',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(V2Space.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Belum ada notifikasi', style: V2Type.h2),
                        const SizedBox(height: V2Space.sm),
                        Text(
                          'Kabar semaian siap pindah, stok menipis, dan panen akan muncul di sini.',
                          textAlign: TextAlign.center,
                          style: V2Type.body.copyWith(color: V2Colors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final unread = _items.where((item) => !item.read).toList();
    final read = _items.where((item) => item.read).toList();
    final groups = <V2NotificationGroup>[
      if (unread.isNotEmpty)
        V2NotificationGroup(
          label: 'Baru',
          items: [
            for (final item in unread)
              V2Notification(
                title: item.title,
                subtitle: item.subtitle,
                icon: _iconFor(item.category),
              ),
          ],
        ),
      if (read.isNotEmpty)
        V2NotificationGroup(
          label: 'Sebelumnya',
          items: [
            for (final item in read)
              V2Notification(
                title: item.title,
                subtitle: item.subtitle,
                icon: _iconFor(item.category),
              ),
          ],
        ),
    ];

    return V2NotificationsPage(
      groups: groups,
      onMarkAllRead: unread.isEmpty ? null : _markAllRead,
    );
  }
}
