import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/sync_queue_item.dart';
import '../data/repositories/nursery_repository.dart';
import '../views/v2/components/v2_penjualan_data.dart';
import 'connected_nursery_viewmodel.dart';
import 'nursery_queue_sink.dart';
import 'v2_sync_queue.dart';
import 'v2_sync_replayer.dart';

/// Target baris antrean untuk penyemaian baru.
const nurseryCreateTarget = 'penyemaian';

/// Target baris antrean untuk pemindahan bibit.
const nurseryTransferTarget = 'pemindahan';

/// Awalan target koreksi penyemaian, mis. `penyemaian:12`.
const nurseryUpdatePrefix = 'penyemaian:';

/// Baris antrean untuk satu tulis semaian yang hasilnya belum pasti.
SyncQueueItem nurseryQueueItem({
  required String key,
  required String target,
  required Map<String, dynamic> body,
  String? subtitle,
  DateTime? createdAt,
}) {
  final tanggal = DateTime.tryParse(
    '${body['tanggal_semai'] ?? body['tanggal_pemindahan'] ?? ''}',
  );
  final fallback = target == nurseryTransferTarget ? 'Pindah tanam' : 'Semai';
  final label = tanggal == null
      ? fallback
      : '$fallback ${formatTanggalPendek(tanggal)}';
  return SyncQueueItem(
    key: key,
    jenis: SyncQueueJenis.semaian,
    subtitle: subtitle ?? label,
    mode: target.startsWith(nurseryUpdatePrefix)
        ? SyncQueueMode.rincian
        : SyncQueueMode.baru,
    target: target,
    payload: jsonEncode(body),
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Menyambungkan [ConnectedNurseryViewModel] v1 ke antrean HP v2.
class V2NurseryQueueSink implements NurseryQueueSink {
  V2NurseryQueueSink(this._queue);

  final V2SyncQueue _queue;

  @override
  Future<void> record({
    required String key,
    required String target,
    required Map<String, dynamic> body,
    String? subtitle,
    DateTime? createdAt,
  }) => _queue.record(
    nurseryQueueItem(
      key: key,
      target: target,
      body: body,
      subtitle: subtitle,
      createdAt: createdAt,
    ),
  );

  @override
  Future<void> remove(String key) => _queue.remove(key);

  @override
  Future<void> fail(String key, String message) =>
      _queue.markFailed(key, message);
}

/// Pengirim baris antrean semaian: penyemaian baru, koreksi penyemaian, dan
/// pemindahan bibit. Semua memakai kunci idempoten yang tersimpan.
class V2NurserySender implements V2SyncSender {
  V2NurserySender(this._repository);

  final NurseryRepository _repository;

  @override
  SyncQueueJenis get jenis => SyncQueueJenis.semaian;

  @override
  Future<void> send(SyncQueueItem item) async {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(item.payload) as Map<String, dynamic>;
    } catch (_) {
      throw const V2SyncRejectedException(
        'Isi antrean semaian tidak bisa dibaca.',
      );
    }
    if (item.target == nurseryTransferTarget) {
      await _repository.transferSowing(
        idempotencyKey: item.key,
        sowingId: '${body['id_penyemaian']}',
        tableId: '${body['id_meja']}',
        transferDate: '${body['tanggal_pemindahan']}',
        plantCount: (body['jumlah_tanaman'] as num).toInt(),
        note: body['keterangan'] as String?,
      );
      return;
    }
    if (item.target == nurseryCreateTarget) {
      await _repository.createSowing(
        sowingDate: '${body['tanggal_semai']}',
        seedCount: (body['jumlah_benih'] as num).toInt(),
        note: body['keterangan'] as String?,
        materials: [
          for (final row in (body['materials'] as List? ?? const []))
            Map<String, dynamic>.from(row as Map),
        ],
        idempotencyKey: item.key,
      );
      return;
    }
    if (item.target.startsWith(nurseryUpdatePrefix)) {
      await _repository.updateSowing(
        item.target.substring(nurseryUpdatePrefix.length),
        seedCount: (body['jumlah_benih'] as num?)?.toInt(),
        note: body['keterangan'] as String?,
        idempotencyKey: item.key,
      );
      return;
    }
    throw const V2SyncRejectedException('Jenis antrean semaian tidak dikenal.');
  }
}

final v2NurserySenderProvider = Provider<V2NurserySender>(
  (ref) => V2NurserySender(ref.watch(nurseryRepositoryProvider)),
);
