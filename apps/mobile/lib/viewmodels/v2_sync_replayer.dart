import '../data/models/sync_queue_item.dart';
import '../data/services/write_outcome.dart';
import 'session_viewmodel.dart';
import 'v2_sync_queue.dart';

/// Penolakan yang pasti: kiriman ulang tidak akan berhasil sampai pengguna
/// memperbaiki atau membuang barisnya. Dipakai pengirim untuk syarat awal yang
/// tidak terpenuhi (mis. baris sudah tidak ada di server).
class V2SyncRejectedException implements Exception {
  const V2SyncRejectedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bentrok versi: versi baris di server sudah berubah, jadi kiriman ulang
/// dengan tiket lama ditolak. Baris ditandai `konflik` dan dialog 11.8 yang
/// memutuskan versi mana yang dipakai.
class V2SyncConflictException implements Exception {
  const V2SyncConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Pengirim satu jenis data dari antrean ke server.
abstract interface class V2SyncSender {
  SyncQueueJenis get jenis;

  /// Mengirim [item] dengan kunci idempotennya. Melempar bila gagal; jenis
  /// galatnya menentukan apakah baris ditandai gagal atau tetap menunggu.
  Future<void> send(SyncQueueItem item);
}

/// Hasil satu putaran sinkron.
class V2SyncRun {
  const V2SyncRun({
    this.sent = 0,
    this.failed = 0,
    this.pending = 0,
    this.waiting = 0,
    this.total = 0,
  });

  /// Berhasil terkirim dan lepas dari antrean.
  final int sent;

  /// Ditolak server; tetap di antrean dengan status gagal.
  final int failed;

  /// Sudah dicoba tetapi jawabannya tidak pasti (jaringan/server).
  final int pending;

  /// Jenisnya belum punya pengirim, jadi tidak dicoba sama sekali.
  final int waiting;

  /// Jumlah baris antrean saat putaran dimulai; dasar teks "x dari y".
  final int total;

  /// Baris yang masih tersimpan di HP setelah putaran ini.
  int get remaining => total - sent;

  bool get empty => total == 0;
}

/// Kemajuan satu baris di dalam putaran sinkron (banner 11.5).
class V2SyncProgress {
  const V2SyncProgress({
    required this.current,
    required this.total,
    required this.item,
    required this.stage,
  });

  /// Urutan baris yang sedang ditangani, mulai dari 1.
  final int current;

  /// Jumlah baris antrean saat putaran dimulai.
  final int total;
  final SyncQueueItem item;
  final V2SyncProgressStage stage;
}

/// Keadaan satu baris saat dilaporkan lewat [V2SyncProgress].
enum V2SyncProgressStage {
  /// Sedang dikirim ke server.
  mengirim,

  /// Sudah diterima server dan lepas dari antrean.
  terkirim,

  /// Ditolak server; tetap di antrean dengan status gagal.
  gagal,

  /// Belum pasti atau belum punya pengirim; tetap di antrean.
  menunggu,
}

/// Mengirim antrean tersimpan berurutan, induk lebih dulu [SyncQueueJenis].
///
/// Hanya jenis yang punya pengirim yang dikirim; sisanya dibiarkan menunggu
/// supaya penambahan alur lain tidak diam-diam membuang datanya.
class V2SyncReplayer {
  V2SyncReplayer({required this.queue, required List<V2SyncSender> senders})
    : _senders = {for (final sender in senders) sender.jenis: sender};

  final V2SyncQueue queue;
  final Map<SyncQueueJenis, V2SyncSender> _senders;

  Future<V2SyncRun> run({
    void Function(V2SyncProgress progress)? onProgress,
  }) async {
    final items = [...queue.items]..sort(_compare);
    final total = items.length;
    var sent = 0;
    var failed = 0;
    var pending = 0;
    var waiting = 0;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final current = index + 1;
      final sender = _senders[item.jenis];
      if (sender == null) {
        waiting++;
        onProgress?.call(
          V2SyncProgress(
            current: current,
            total: total,
            item: item,
            stage: V2SyncProgressStage.menunggu,
          ),
        );
        continue;
      }
      onProgress?.call(
        V2SyncProgress(
          current: current,
          total: total,
          item: item,
          stage: V2SyncProgressStage.mengirim,
        ),
      );
      try {
        await sender.send(item);
        await queue.remove(item.key);
        sent++;
        onProgress?.call(
          V2SyncProgress(
            current: current,
            total: total,
            item: item,
            stage: V2SyncProgressStage.terkirim,
          ),
        );
      } catch (error) {
        if (error is V2SyncConflictException) {
          await queue.markConflict(item.key, error.message);
          failed++;
          onProgress?.call(
            V2SyncProgress(
              current: current,
              total: total,
              item: item,
              stage: V2SyncProgressStage.gagal,
            ),
          );
        } else if (_permanent(error)) {
          await queue.markFailed(item.key, serviceError(error));
          failed++;
          onProgress?.call(
            V2SyncProgress(
              current: current,
              total: total,
              item: item,
              stage: V2SyncProgressStage.gagal,
            ),
          );
        } else {
          pending++;
          onProgress?.call(
            V2SyncProgress(
              current: current,
              total: total,
              item: item,
              stage: V2SyncProgressStage.menunggu,
            ),
          );
        }
      }
    }
    return V2SyncRun(
      sent: sent,
      failed: failed,
      pending: pending,
      waiting: waiting,
      total: total,
    );
  }

  /// Penolakan pasti: syarat awal pengirim, atau jawaban API dari jalur tulis.
  /// Jawaban lain (jaringan, 5xx, halaman proxy) masih belum pasti.
  ///
  /// Kiriman ini adalah percobaan baru dengan kunci lama, jadi kiriman pertama
  /// yang tidak tersimpan dijawab 4xx secara pasti (`wasUncertain: false`).
  static bool _permanent(Object error) {
    if (error is V2SyncRejectedException) return true;
    return !writeStaysUncertain(error, wasUncertain: false);
  }

  /// Induk lebih dulu: urutan [SyncQueueJenis] sudah semaian→stok→panen→
  /// penjualan→rusak, lalu urutan catat.
  static int _compare(SyncQueueItem a, SyncQueueItem b) {
    final rank = a.jenis.index.compareTo(b.jenis.index);
    if (rank != 0) return rank;
    final time = a.createdAt.compareTo(b.createdAt);
    return time != 0 ? time : a.key.compareTo(b.key);
  }
}
