import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/notification_read_store.dart';
import 'session_viewmodel.dart';

/// Status "sudah dibaca" notifikasi: daftar id di memori, simpanan tahan-tutup
/// di HP (D-23).
class V2NotificationRead extends StateNotifier<Set<String>> {
  V2NotificationRead({
    required this.openStore,
    required this.serverOrigin,
    required this.userId,
  }) : super(const {});

  final Future<NotificationReadStore?> Function() openStore;
  final String serverOrigin;
  final String userId;
  Future<NotificationReadStore?>? _store;

  /// Id yang sedang dianggap sudah dibaca.
  Set<String> get readIds => state;

  /// Membuka penyimpanan sekali per proses, lalu dipakai ulang.
  Future<NotificationReadStore?> _open() => _store ??= openStore();

  /// Memuat status tersimpan (dipanggil sekali saat controller dibuat).
  Future<void> load() async {
    final store = await _open();
    if (store == null || !mounted) return;
    final ids = await store.readIds(serverOrigin: serverOrigin, userId: userId);
    if (!mounted) return;
    state = Set.unmodifiable(ids);
  }

  /// Menandai satu notifikasi sudah dibaca.
  Future<void> markRead(String notifId) async {
    if (state.contains(notifId)) return;
    final store = await _open();
    await store?.markRead(
      serverOrigin: serverOrigin,
      userId: userId,
      notifId: notifId,
      readAt: DateTime.now(),
    );
    if (!mounted) return;
    state = Set.unmodifiable({...state, notifId});
  }

  /// Menandai sekumpulan notifikasi sudah dibaca sekaligus.
  Future<void> markAll(Iterable<String> notifIds) async {
    final baru = notifIds.where((id) => !state.contains(id)).toList();
    if (baru.isEmpty) return;
    final store = await _open();
    for (final id in baru) {
      await store?.markRead(
        serverOrigin: serverOrigin,
        userId: userId,
        notifId: id,
        readAt: DateTime.now(),
      );
    }
    if (!mounted) return;
    state = Set.unmodifiable({...state, ...baru});
  }
}

/// Status baca notifikasi pengguna yang sedang masuk.
///
/// Tanpa pengguna (atau tanpa plugin basis data) status tetap ada di memori.
final v2NotificationReadProvider =
    StateNotifierProvider.autoDispose<V2NotificationRead, Set<String>>((ref) {
      final user = ref.watch(sessionProvider.select((state) => state.user));
      final origin = ref.watch(apiClientProvider).serverOrigin;
      final controller = V2NotificationRead(
        openStore: NotificationReadStore.open,
        serverOrigin: origin,
        userId: user?.id ?? '',
      );
      unawaited(controller.load());
      return controller;
    });
