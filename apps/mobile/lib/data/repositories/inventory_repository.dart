import '../models/inventory_record.dart';
import '../services/api_client.dart';
import '../services/inventory_cache.dart';

class InventoryRepository {
  InventoryRepository(this._api, this._cache, {required this.userId});
  final ApiClient _api;
  final Future<InventoryCache> _cache;
  final String userId;

  Future<InventorySnapshot?> cached() async =>
      (await _cache).read(serverOrigin: _api.serverOrigin, userId: userId);

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
      // B006 exposes individual balances; keep concurrency bounded to one.
      for (final master in data) {
        if (master is! Map<String, dynamic> ||
            master['id_inventaris'] is! String ||
            !RegExp(r'^[1-9][0-9]*$').hasMatch(master['id_inventaris'])) {
          throw const FormatException('Identitas inventaris tidak valid.');
        }
        final id = master['id_inventaris'] as String;
        if (!ids.add(id)) throw const FormatException('Inventaris duplikat.');
        final balance = await _api.get('inventaris/$id/saldo');
        if (balance['data'] is! Map<String, dynamic>) {
          throw const FormatException('Saldo inventaris tidak valid.');
        }
        records.add(InventoryRecord.fromApi(master, balance['data']));
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
