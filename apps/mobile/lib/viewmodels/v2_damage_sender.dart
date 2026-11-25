import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/damage_record.dart';
import '../data/models/sync_queue_item.dart';
import '../data/repositories/damage_repository.dart';
import 'damage_queue_sink.dart';
import 'damage_viewmodel.dart';
import 'v2_sync_queue.dart';
import 'v2_sync_replayer.dart';

/// Target baris antrean untuk laporan kerusakan baru.
const damageCreateTarget = 'kerusakan';

/// Awalan target baris antrean untuk catatan batch, mis. `batch:12`.
const damageBatchPrefix = 'batch:';

/// Awalan target baris antrean untuk koreksi laporan, mis. `kerusakan:9`.
const damageUpdatePrefix = 'kerusakan:';

/// Baris antrean untuk satu tulis kerusakan yang hasilnya belum pasti.
SyncQueueItem damageQueueItem({
  required String key,
  required String target,
  required Map<String, dynamic> body,
  required String subtitle,
  DateTime? createdAt,
}) => SyncQueueItem(
  key: key,
  jenis: SyncQueueJenis.rusak,
  subtitle: subtitle,
  mode: target == damageCreateTarget
      ? SyncQueueMode.baru
      : SyncQueueMode.rincian,
  target: target,
  payload: jsonEncode(body),
  createdAt: createdAt ?? DateTime.now(),
);

/// Menyambungkan [DamageViewModel] v1 ke antrean HP v2.
class V2DamageQueueSink implements DamageQueueSink {
  V2DamageQueueSink(this._queue);

  final V2SyncQueue _queue;

  @override
  Future<void> record({
    required String key,
    required String target,
    required Map<String, dynamic> body,
    required String subtitle,
    DateTime? createdAt,
  }) => _queue.record(
    damageQueueItem(
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

/// Pengirim baris antrean rusak: laporan baru, catatan batch, dan koreksi
/// laporan. Semua memakai kunci idempoten yang tersimpan.
class V2DamageSender implements V2SyncSender {
  V2DamageSender(this._repository);

  final DamageRepository _repository;

  @override
  SyncQueueJenis get jenis => SyncQueueJenis.rusak;

  @override
  Future<void> send(SyncQueueItem item) async {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(item.payload) as Map<String, dynamic>;
    } catch (_) {
      throw const V2SyncRejectedException(
        'Isi antrean rusak tidak bisa dibaca.',
      );
    }
    if (item.target == damageCreateTarget) {
      await _repository.createDamage(
        DamageDraft(
          transferId: '${body['id_pemindahan']}',
          date: '${body['tanggal_kejadian']}',
          plantCount: (body['jumlah_tanaman'] as num).toInt(),
          category: '${body['jenis_kerusakan']}',
          note: body['keterangan'] as String?,
        ),
        item.key,
      );
      return;
    }
    if (item.target.startsWith(damageBatchPrefix)) {
      await _repository.updateTransfer(
        item.target.substring(damageBatchPrefix.length),
        note: body['keterangan'] as String?,
        idempotencyKey: item.key,
      );
      return;
    }
    if (item.target.startsWith(damageUpdatePrefix)) {
      await _repository.updateDamage(
        item.target.substring(damageUpdatePrefix.length),
        date: body['tanggal_kejadian'] as String?,
        plantCount: (body['jumlah_tanaman'] as num?)?.toInt(),
        category: body['jenis_kerusakan'] as String?,
        note: body['keterangan'] as String?,
        idempotencyKey: item.key,
      );
      return;
    }
    throw const V2SyncRejectedException('Jenis antrean rusak tidak dikenal.');
  }
}

final v2DamageSenderProvider = Provider<V2DamageSender>(
  (ref) => V2DamageSender(ref.watch(damageRepositoryProvider)),
);
