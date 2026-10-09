import '../../core/uuid.dart';
import '../models/inventory_record.dart';
import '../models/jenis_inventaris_record.dart';
import '../models/stock_movement_record.dart';
import '../services/api_client.dart';
import '../services/inventory_cache.dart';

class InventoryRepository {
  InventoryRepository(this._api, this._cache, {required this.userId});
  final ApiClient _api;
  final Future<InventoryCache> _cache;
  final String userId;
  String get serverOrigin => _api.serverOrigin;

  Future<InventorySnapshot?> cached() async =>
      (await _cache).read(serverOrigin: _api.serverOrigin, userId: userId);

  Future<List<JenisInventarisRecord>> fetchCategories() async {
    final response = await _api.get(
      'jenis-inventaris',
      query: {'limit': '100', 'status_aktif': '1'},
    );
    final data = response['data'];
    if (data is! List) throw const FormatException('Kategori tidak valid.');
    return data
        .map(
          (json) =>
              JenisInventarisRecord.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<InventoryRecord> createItem({
    required String categoryId,
    String? medicineId,
    required String name,
    required String unit,
    String? minimum,
    String? idempotencyKey,
  }) async {
    final response = await _api.post(
      'inventaris',
      headers: {'Idempotency-Key': idempotencyKey ?? generateUuidV4()},
      body: {
        'id_jenis_inventaris': categoryId,
        'id_obat': ?medicineId,
        'nama_barang': name,
        'satuan': unit,
        if (minimum != null && minimum.isNotEmpty) 'stok_minimum': minimum,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic> || data['id_inventaris'] is! String) {
      throw const FormatException('Gagal membuat barang inventaris.');
    }
    return InventoryRecord.fromApi(data, data);
  }

  Future<InventoryRecord> updateItem(
    String id, {
    String? categoryId,
    String? medicineId,
    String? name,
    String? unit,
    String? minimum,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{};
    if (categoryId != null) body['id_jenis_inventaris'] = categoryId;
    if (medicineId != null) body['id_obat'] = medicineId;
    if (name != null) body['nama_barang'] = name;
    if (unit != null) body['satuan'] = unit;
    if (minimum != null) {
      body['stok_minimum'] = minimum.isEmpty ? null : minimum;
    }

    final response = await _api.patch(
      'inventaris/$id',
      body: body,
      headers: {'Idempotency-Key': idempotencyKey ?? generateUuidV4()},
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gagal memperbarui barang inventaris.');
    }
    return InventoryRecord.fromApi(data, data);
  }

  Future<void> deactivateItem(String id) async {
    await _api.post('inventaris/$id/deactivate');
  }

  Future<StockMovementRecord> recordStockMovement({
    required String direction,
    required List<Map<String, String>> details,
    String? note,
    String? idempotencyKey,
  }) async {
    final response = await _api.post(
      'stok',
      headers: {'Idempotency-Key': idempotencyKey ?? generateUuidV4()},
      body: {
        'jenis_stok': direction,
        'details': details,
        if (note != null && note.isNotEmpty) 'keterangan': note,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gagal mencatat mutasi stok.');
    }
    return StockMovementRecord.fromJson(data);
  }

  Future<List<StockMovementRecord>> fetchStockHistory({
    String? inventoryId,
    String? direction,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get(
      'stok',
      query: {
        'page': '$page',
        'limit': '$limit',
        'id_inventaris': ?inventoryId,
        'jenis_stok': ?direction,
      },
    );
    final data = response['data'];
    if (data is! List) throw const FormatException('Riwayat stok tidak valid.');
    return data
        .map(
          (json) => StockMovementRecord.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<InventorySnapshot> refresh() async {
    final sessionGeneration = _api.sessionGeneration;
    final records = <InventoryRecord>[];
    final ids = <String>{};
    var page = 1;
    var totalPages = 1;
    int? expectedTotal;
    do {
      final response = await _api.get(
        'inventaris',
        query: {'page': '$page', 'limit': '20', 'status_aktif': '1'},
      );
      final data = response['data'];
      final meta = response['meta'];
      if (data is! List ||
          meta is! Map ||
          meta['total_pages'] is! int ||
          meta['total'] is! int ||
          meta['page'] != page ||
          (meta['total_pages'] as int) < 0 ||
          (meta['total'] as int) < 0 ||
          (expectedTotal != null && meta['total'] != expectedTotal)) {
        throw const FormatException('Daftar inventaris tidak valid.');
      }
      expectedTotal = meta['total'] as int;
      totalPages = meta['total_pages'];
      for (final master in data) {
        if (master is! Map<String, dynamic> ||
            master['id_inventaris'] is! String ||
            !RegExp(r'^[1-9][0-9]*$').hasMatch(master['id_inventaris'])) {
          throw const FormatException('Identitas inventaris tidak valid.');
        }
        final id = master['id_inventaris'] as String;
        if (!ids.add(id)) throw const FormatException('Inventaris duplikat.');
        records.add(InventoryRecord.fromApi(master, master));
      }
      page++;
    } while (page <= totalPages);
    if (records.length != expectedTotal) {
      throw const FormatException('Daftar inventaris tidak lengkap.');
    }
    final fetchedAt = DateTime.now().toUtc();
    final cache = await _cache;
    _api.requireSessionGeneration(sessionGeneration);
    await cache.replace(
      serverOrigin: _api.serverOrigin,
      userId: userId,
      records: records,
      fetchedAt: fetchedAt,
    );
    return InventorySnapshot(
      records: List.unmodifiable(records),
      fetchedAt: fetchedAt,
    );
  }
}
