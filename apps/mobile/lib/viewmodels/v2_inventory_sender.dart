import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/sync_queue_item.dart';
import '../data/repositories/inventory_repository.dart';
import 'connected_inventory_viewmodel.dart';
import 'inventory_queue_sink.dart';
import 'session_viewmodel.dart';
import 'v2_sync_queue.dart';
import 'v2_sync_replayer.dart';

/// Target baris antrean untuk barang inventaris baru.
const inventoryCreateTarget = 'inventaris';

/// Awalan target koreksi barang inventaris, mis. `inventaris:12`.
const inventoryUpdatePrefix = 'inventaris:';

/// Target baris antrean untuk mutasi stok.
const inventoryStockTarget = 'stok';

/// Baris antrean untuk satu tahap tulis inventaris yang belum pasti.
SyncQueueItem inventoryQueueItem({
  required String key,
  required String target,
  required Map<String, dynamic> body,
  required String subtitle,
  DateTime? createdAt,
}) => SyncQueueItem(
  key: key,
  jenis: SyncQueueJenis.stok,
  subtitle: subtitle,
  mode: switch (target) {
    inventoryCreateTarget || inventoryStockTarget => SyncQueueMode.baru,
    _ => SyncQueueMode.rincian,
  },
  target: target,
  payload: jsonEncode(body),
  createdAt: createdAt ?? DateTime.now(),
);

/// Menyambungkan [ConnectedInventoryViewModel] v1 ke antrean HP v2.
class V2InventoryQueueSink implements InventoryQueueSink {
  V2InventoryQueueSink(this._queue);

  final V2SyncQueue _queue;

  @override
  Future<void> record({
    required String key,
    required String target,
    required Map<String, dynamic> body,
    required String subtitle,
    DateTime? createdAt,
  }) => _queue.record(
    inventoryQueueItem(
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

/// Pengirim baris antrean stok: barang baru, koreksi barang, dan mutasi stok.
class V2InventorySender implements V2SyncSender {
  V2InventorySender(this._repository);

  final InventoryRepository _repository;

  @override
  SyncQueueJenis get jenis => SyncQueueJenis.stok;

  @override
  Future<void> send(SyncQueueItem item) async {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(item.payload) as Map<String, dynamic>;
    } catch (_) {
      throw const V2SyncRejectedException(
        'Isi antrean stok tidak bisa dibaca.',
      );
    }
    if (item.target == inventoryStockTarget) {
      await _repository.recordStockMovement(
        direction: '${body['jenis_stok']}',
        details: [
          for (final row in (body['details'] as List? ?? const []))
            Map<String, String>.from(row as Map),
        ],
        note: body['keterangan'] as String?,
        idempotencyKey: item.key,
      );
      return;
    }
    if (item.target == inventoryCreateTarget) {
      await _repository.createItem(
        categoryId: '${body['id_jenis_inventaris']}',
        name: '${body['nama_barang']}',
        unit: '${body['satuan']}',
        minimum: body['stok_minimum'] as String?,
        idempotencyKey: item.key,
      );
      return;
    }
    if (item.target.startsWith(inventoryUpdatePrefix)) {
      await _repository.updateItem(
        item.target.substring(inventoryUpdatePrefix.length),
        categoryId: '${body['id_jenis_inventaris']}',
        name: '${body['nama_barang']}',
        unit: '${body['satuan']}',
        minimum: body['stok_minimum'] as String?,
        idempotencyKey: item.key,
      );
      return;
    }
    throw const V2SyncRejectedException(
      'Jenis antrean stok tidak dikenal.',
    );
  }
}

final v2InventorySenderProvider = Provider<V2InventorySender>((ref) {
  final user = ref.watch(sessionProvider.select((state) => state.user));
  return V2InventorySender(
    InventoryRepository(
      ref.watch(apiClientProvider),
      ref.watch(inventoryCacheProvider),
      userId: user?.id ?? '',
    ),
  );
});
