import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/sync_queue_item.dart';
import '../data/services/sync_queue.dart';
import 'session_viewmodel.dart';

/// Antrean sinkron alur v2: daftar di memori, simpanan tahan-tutup di HP.
///
/// Baris ditambahkan saat sebuah tulis gagal tanpa jawaban pasti, dan dilepas
/// setelah berhasil dikirim (tahap replay menyusul).
class V2SyncQueue extends StateNotifier<List<SyncQueueItem>> {
  V2SyncQueue({
    required this.openStore,
    required this.serverOrigin,
    required this.userId,
  }) : super(const []);

  final Future<SyncQueueStore?> Function() openStore;
  final String serverOrigin;
  final String userId;
  Future<SyncQueueStore?>? _store;

  /// Antrean yang sedang tampil; dibaca halaman 11 lewat beranda.
  List<SyncQueueItem> get items => state;

  /// Membuka penyimpanan sekali per proses, lalu dipakai ulang.
  Future<SyncQueueStore?> _open() => _store ??= openStore();

  /// Memuat antrean tersimpan (dipanggil sekali saat controller dibuat).
  Future<void> load() async {
    final store = await _open();
    if (store == null || !mounted) return;
    final items = await store.list(serverOrigin: serverOrigin, userId: userId);
    if (!mounted) return;
    state = List.unmodifiable(items);
  }

  /// Menyimpan satu tulis yang gagal dikirim; kunci sama menimpa baris lama.
  Future<void> record(SyncQueueItem item) async {
    final store = await _open();
    await store?.enqueue(
      serverOrigin: serverOrigin,
      userId: userId,
      item: item,
    );
    if (!mounted) return;
    final items = <SyncQueueItem>[
      for (final existing in state)
        if (existing.key != item.key) existing,
      item,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = List.unmodifiable(items);
  }

  /// Melepas satu baris setelah berhasil dikirim.
  Future<void> remove(String key) async {
    final store = await _open();
    await store?.remove(serverOrigin: serverOrigin, userId: userId, key: key);
    if (!mounted) return;
    state = List.unmodifiable([
      for (final item in state)
        if (item.key != key) item,
    ]);
  }
}

/// Antrean sinkron pengguna yang sedang masuk.
///
/// Tanpa pengguna (atau tanpa plugin basis data) antrean tetap ada di memori;
/// halaman 11 hanya menampilkannya bila berisi.
final v2SyncQueueProvider =
    StateNotifierProvider.autoDispose<V2SyncQueue, List<SyncQueueItem>>((ref) {
      final user = ref.watch(sessionProvider.select((state) => state.user));
      final origin = ref.watch(apiClientProvider).serverOrigin;
      final controller = V2SyncQueue(
        openStore: SyncQueueStore.open,
        serverOrigin: origin,
        userId: user?.id ?? '',
      );
      unawaited(controller.load());
      return controller;
    });
