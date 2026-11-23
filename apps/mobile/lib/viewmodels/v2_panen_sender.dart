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
///
/// Sebagai [V2SyncConflictResolver], jenis ini juga menyelesaikan baris
/// `konflik` di dialog 11.8, supaya koreksi panen yang bentrok versi tidak
/// menjadi buntu di halaman Sinkron.
class V2PanenSender implements V2SyncSender, V2SyncConflictResolver {
  V2PanenSender(this._repository, [this._queue]);

  final HarvestRepository _repository;
  final V2SyncQueue? _queue;

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

  /// Menyelesaikan baris `konflik` panen menurut pilihan dialog 11.8.
  ///
  /// "Pakai data server" membuang isi HP. "Kirim ulang punya saya" memuat versi
  /// panen terbaru dari server, memakainya sebagai tiket, lalu menulis ulang
  /// isi HP — tulis terakhir menang tanpa menabrak pemeriksaan versi.
  @override
  Future<void> resolveConflict(
    SyncQueueItem item, {
    required bool useServer,
  }) async {
    if (useServer) {
      await _queue?.remove(item.key);
      return;
    }
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(item.payload) as Map<String, dynamic>;
    } catch (_) {
      throw const V2SyncRejectedException(
        'Isi antrean panen tidak bisa dibaca.',
      );
    }
    final latest = await _repository.getHarvest(item.target);
    final version = latest.version;
    if (version == null) {
      throw const V2SyncRejectedException(
        'Panen sudah tidak ada di server; pakai data server.',
      );
    }
    try {
      await _repository.write(item.target, {
        ...body,
        'expected_version': version,
      }, item.key);
    } on ApiException catch (error) {
      if (error.code == 'HARVEST_VERSION_CONFLICT') {
        throw V2SyncConflictException(error.message);
      }
      rethrow;
    }
    await _queue?.remove(item.key);
  }
}

final v2PanenSenderProvider = Provider<V2PanenSender>(
  (ref) => V2PanenSender(
    ref.watch(harvestRepositoryProvider),
    ref.watch(v2SyncQueueProvider.notifier),
  ),
);
