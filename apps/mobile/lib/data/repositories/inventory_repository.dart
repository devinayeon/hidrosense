import '../../core/uuid.dart';
import '../models/inventory_record.dart';
import '../models/jenis_inventaris_record.dart';
import '../models/obat_katalog_record.dart';
import '../models/obat_record.dart';
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

  Future<List<JenisInventarisRecord>> fetchCategories() =>
      fetchInventoryCategories(_api);

  Future<InventoryRecord> createItem({
    required String categoryId,
    String? medicineId,
    String? katalogId,
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
        'id_katalog': ?katalogId,
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
    String? katalogId,
    String? name,
    String? unit,
    String? minimum,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{};
    if (categoryId != null) body['id_jenis_inventaris'] = categoryId;
    if (medicineId != null) body['id_obat'] = medicineId;
    if (katalogId != null) body['id_katalog'] = katalogId;
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
    await _api.post(
      'inventaris/$id/deactivate',
      headers: {'Idempotency-Key': generateUuidV4()},
    );
  }

  /// Mengaktifkan kembali barang yang diarsipkan.
  Future<void> activateItem(String id) async {
    await _api.post(
      'inventaris/$id/activate',
      headers: {'Idempotency-Key': generateUuidV4()},
    );
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

  /// Riwayat stok terbaru, terbaru lebih dulu.
  ///
  /// `GET /stok` mengurutkan dari transaksi terlama, jadi halaman terakhir
  /// berisi transaksi terbaru. Kartu "Riwayat" hanya menampilkan tiga baris
  /// pertama, karena itu halaman terakhir (dan halaman sebelumnya bila halaman
  /// terakhir belum penuh) diambil lalu dibalik. Dengan begitu potongan stok
  /// dari perawatan yang baru diterima tidak tertutup catatan lama.
  Future<List<StockMovementRecord>> fetchLatestStockHistory({
    required String inventoryId,
    int limit = 20,
  }) async {
    final probe = await _api.get(
      'stok',
      query: {'page': '1', 'limit': '1', 'id_inventaris': inventoryId},
    );
    final total = _metaInt(probe, 'total');
    if (total <= 0) return const <StockMovementRecord>[];
    final lastPage = (total + limit - 1) ~/ limit;
    final lastPageSize = total - (lastPage - 1) * limit;
    final firstPage = lastPageSize < limit && lastPage > 1
        ? lastPage - 1
        : lastPage;
    final rows = <StockMovementRecord>[];
    for (var page = firstPage; page <= lastPage; page++) {
      final response = await _api.get(
        'stok',
        query: {
          'page': '$page',
          'limit': '$limit',
          'id_inventaris': inventoryId,
        },
      );
      final data = response['data'];
      if (data is! List) {
        throw const FormatException('Riwayat stok tidak valid.');
      }
      rows.addAll(
        data.map(
          (json) => StockMovementRecord.fromJson(json as Map<String, dynamic>),
        ),
      );
    }
    // Halaman diambil dari terlama ke terbaru; balik supaya terbaru di atas.
    return rows.reversed.take(limit).toList();
  }

  Future<InventorySnapshot> refresh() async {
    final sessionGeneration = _api.sessionGeneration;
    final records = <InventoryRecord>[];
    final ids = <String>{};
    var page = 1;
    var totalPages = 1;
    int? expectedTotal;
    do {
      // Tanpa `status_aktif`, server mengirim barang aktif **dan** arsip, supaya
      // chip "Arsip" di daftar stok punya datanya. Penyaring aktif tetap dipakai
      // di klien (`activeRecords`) untuk kartu stok menipis dan pemilihan bahan.
      final response = await _api.get(
        'inventaris',
        query: {'page': '$page', 'limit': '20'},
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

Future<List<JenisInventarisRecord>> fetchInventoryCategories(
  ApiClient api,
) async {
  final response = await api.get(
    'jenis-inventaris',
    query: {'limit': '100', 'status_aktif': '1'},
  );
  final data = response['data'];
  if (data is! List) throw const FormatException('Kategori tidak valid.');
  return data
      .map(
        (json) => JenisInventarisRecord.fromJson(json as Map<String, dynamic>),
      )
      .toList();
}

Future<List<ObatRecord>> fetchMedicines(ApiClient api) async {
  final response = await api.get(
    'obat',
    query: {'limit': '100', 'status_aktif': '1'},
  );
  final data = response['data'];
  if (data is! List) throw const FormatException('Daftar obat tidak valid.');
  return data
      .map((json) => ObatRecord.fromJson(json as Map<String, dynamic>))
      .toList();
}

/// Katalog obat bawaan (`obat_katalog`) untuk dropdown barang jenis Obat.
Future<List<ObatKatalogRecord>> fetchObatKatalog(ApiClient api) async {
  final response = await api.get('obat-katalog', query: {'limit': '100'});
  final data = response['data'];
  if (data is! List) {
    throw const FormatException('Daftar katalog obat tidak valid.');
  }
  return data
      .map((json) => ObatKatalogRecord.fromJson(json as Map<String, dynamic>))
      .toList();
}

/// Angka `meta` dari respons daftar; 0 bila meta atau kuncinya tidak ada.
int _metaInt(Map<String, dynamic> response, String key) {
  final meta = response['meta'];
  if (meta is! Map) return 0;
  final value = meta[key];
  return value is int ? value : int.tryParse('$value') ?? 0;
}
