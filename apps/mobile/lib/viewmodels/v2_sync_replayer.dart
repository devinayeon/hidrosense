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

/// Pengirim satu jenis data dari antrean ke server.
abstract interface class V2SyncSender {
  SyncQueueJenis get jenis;

  /// Mengirim [item] dengan kunci idempotennya. Melempar bila gagal; jenis
  /// galatnya menentukan apakah baris ditandai gagal atau tetap menunggu.
  Future<void> send(SyncQueueItem item);
}

/// Hasil satu putaran sinkron.
class V2SyncRun {
  const V2SyncRun({this.sent = 0, this.failed = 0, this.pending = 0});

  /// Berhasil terkirim dan lepas dari antrean.
  final int sent;

  /// Ditolak server; tetap di antrean dengan status gagal.
  final int failed;

  /// Masih tidak pasti (jaringan/server); tetap menunggu.
  final int pending;

  bool get empty => sent == 0 && failed == 0 && pending == 0;
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

  Future<V2SyncRun> run() async {
    final items = [...queue.items]..sort(_compare);
    var sent = 0;
    var failed = 0;
    var pending = 0;
    for (final item in items) {
      final sender = _senders[item.jenis];
      if (sender == null) continue;
      try {
        await sender.send(item);
        await queue.remove(item.key);
        sent++;
      } catch (error) {
        if (_permanent(error)) {
          await queue.markFailed(item.key, serviceError(error));
          failed++;
        } else {
          pending++;
        }
      }
    }
    return V2SyncRun(sent: sent, failed: failed, pending: pending);
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
