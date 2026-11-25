import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/sync_status_repository.dart';
import '../data/services/local_kv_store.dart';
import 'session_viewmodel.dart';
import 'v2_sync_replayer.dart';

/// Membuka penyimpanan kunci-nilai sekali per proses.
final localKvStoreProvider = Provider<Future<LocalKvStore?>>(
  (ref) => LocalKvStore.open(),
);

final syncStatusRepositoryProvider = Provider<SyncStatusRepository>((ref) {
  final user = ref.watch(sessionProvider.select((state) => state.user?.id));
  final store = ref.watch(localKvStoreProvider);
  return SyncStatusRepository(
    ref.watch(apiClientProvider),
    () => store,
    userId: user ?? '',
  );
});

/// Jam sinkron terakhir pengguna yang sedang masuk; `null` berarti belum
/// pernah sinkron di HP ini.
///
/// Nilai dari HP langsung tampil, lalu disegarkan dari server di latar. Berbeda
/// dari jam contoh desain, angka ini tidak kembali ke awal saat pengguna
/// keluar dari menu Sinkron atau menutup aplikasi.
class V2SyncStatus extends StateNotifier<DateTime?> {
  V2SyncStatus(this._repository) : super(null) {
    unawaited(load());
  }

  final SyncStatusRepository _repository;

  Future<void> load() async {
    final local = await _repository.readLocal();
    if (!mounted) return;
    if (local != null) state = local;
    final fresh = await _repository.refresh();
    if (!mounted) return;
    if (fresh != null) state = fresh;
  }

  /// Menyegarkan dari server; dipakai halaman Sinkron saat dibuka.
  Future<DateTime?> refresh() async {
    final fresh = await _repository.refresh();
    if (mounted && fresh != null) state = fresh;
    return fresh ?? state;
  }

  /// Satu putaran sinkron yang selesai penuh dicatat di sini. Hasilnya menjadi
  /// jam yang tampil di ringkasan "Terakhir sinkron".
  Future<DateTime> markSynced({bool trustLocal = false}) async {
    final stamped = await _repository.markSynced(trustLocal: trustLocal);
    if (mounted) state = stamped;
    return stamped;
  }
}

final v2SyncStatusProvider = StateNotifierProvider<V2SyncStatus, DateTime?>(
  (ref) => V2SyncStatus(ref.watch(syncStatusRepositoryProvider)),
);

/// Menjalankan antrean lalu mencatat jam sinkron bila semuanya sudah di server.
///
/// Jam hanya dicatat saat tidak ada baris tersisa. Kalau antrean kosong dan
/// server tidak terjangkau, tidak ada bukti sambungan: hasilnya "belum pasti"
/// (offline), bukan "Sinkron selesai". Kalau ada data yang baru terkirim,
/// sinkronnya nyata walau pencatatan jam gagal.
Future<V2SyncRun> v2SyncRound({
  required Future<V2SyncRun> Function() run,
  required Future<DateTime> Function({bool trustLocal}) markSynced,
}) async {
  final result = await run();
  if (result.remaining > 0) return result;
  try {
    final at = await markSynced(trustLocal: result.sent > 0);
    return result.withSyncedAt(at);
  } catch (_) {
    return V2SyncRun(
      sent: result.sent,
      failed: result.failed,
      pending: result.pending + 1,
      waiting: result.waiting,
      total: result.total + 1,
    );
  }
}
