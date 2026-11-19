import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/sync_queue_item.dart';
import '../data/repositories/harvest_repository.dart';
import '../data/services/api_client.dart';
import '../views/v2/components/v2_penjualan_data.dart';
import 'harvest_queue_sink.dart';
import 'panen_viewmodel.dart';
import 'v2_sync_queue.dart';
import 'v2_sync_replayer.dart';

/// Baris antrean untuk satu tulis panen yang hasilnya belum pasti.
///
/// Mode mengikuti isi kiriman: `create` → [SyncQueueMode.baru], koreksi dengan
/// rincian → [SyncQueueMode.rincian], koreksi header saja →
/// [SyncQueueMode.header].
SyncQueueItem harvestQueueItem({
  required String key,
  required String target,
  required Map<String, dynamic> body,
  DateTime? createdAt,
}) {
  final tanggal = DateTime.tryParse('${body['tanggal_panen'] ?? ''}');
  final label = tanggal == null
      ? 'Panen'
      : 'Panen ${formatTanggalPendek(tanggal)}';
  return SyncQueueItem(
    key: key,
    jenis: SyncQueueJenis.panen,
    subtitle: target == 'create' ? label : 'Koreksi ${label.toLowerCase()}',
    mode: target == 'create'
        ? SyncQueueMode.baru
        : body['details'] is List
        ? SyncQueueMode.rincian
        : SyncQueueMode.header,
    target: target,
    payload: jsonEncode(body),
    expectedVersion: body['expected_version'] as String?,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Menyambungkan [PanenViewModel] v1 ke antrean HP v2.
class V2HarvestQueueSink implements HarvestQueueSink {
  V2HarvestQueueSink(this._queue);

  final V2SyncQueue _queue;

  @override
  Future<void> record({
    required String key,
    required String target,
    required Map<String, dynamic> body,
    DateTime? createdAt,
  }) => _queue.record(
    harvestQueueItem(
      key: key,
      target: target,
      body: body,
      createdAt: createdAt,
    ),
  );

  @override
  Future<void> remove(String key) => _queue.remove(key);

  @override
  Future<void> fail(String key, String message) =>
      _queue.markFailed(key, message);
}

/// Pengirim baris antrean panen: memakai isi dan kunci yang tersimpan apa
/// adanya, jadi kiriman ulang tidak mencatat panen kedua.
class V2PanenSender implements V2SyncSender {
  V2PanenSender(this._repository);

  final HarvestRepository _repository;

  @override
  SyncQueueJenis get jenis => SyncQueueJenis.panen;

  @override
  Future<void> send(SyncQueueItem item) async {
    final body = jsonDecode(item.payload) as Map<String, dynamic>;
    try {
      await _repository.write(item.target, body, item.key);
    } on ApiException catch (error) {
      if (error.code == 'HARVEST_VERSION_CONFLICT') {
        throw V2SyncConflictException(error.message);
      }
      rethrow;
    }
  }
}

final v2PanenSenderProvider = Provider<V2PanenSender>(
  (ref) => V2PanenSender(ref.watch(harvestRepositoryProvider)),
);
