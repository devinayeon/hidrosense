import '../models/sale_record.dart';
import '../services/api_client.dart';

class SalesRepository {
  SalesRepository(this._api);
  final ApiClient _api;
  String get serverOrigin => _api.serverOrigin;

  Future<List<SaleRecord>> listSales() async {
    final rows = <Map<String, dynamic>>[];
    int? total, pages;
    var page = 1;
    do {
      final response = await _api.get(
        'penjualan',
        query: {'page': '$page', 'limit': '100'},
      );
      final data = response['data'], meta = response['meta'];
      if (data is! List ||
          meta is! Map ||
          meta['page'] != page ||
          meta['limit'] != 100 ||
          meta['total'] is! int ||
          meta['total'] < 0 ||
          meta['total_pages'] is! int ||
          meta['total_pages'] != ((meta['total'] as int) / 100).ceil() ||
          (total != null && total != meta['total']) ||
          (pages != null && pages != meta['total_pages'])) {
        throw const FormatException('Halaman penjualan berubah. Muat ulang.');
      }
      total = meta['total'];
      pages = meta['total_pages'];
      final expected = total! == 0
          ? 0
          : page < pages!
          ? 100
          : total - (page - 1) * 100;
      if (data.length != expected) {
        throw const FormatException('Daftar penjualan tidak lengkap.');
      }
      for (final row in data) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException('Daftar penjualan tidak valid.');
        }
        saleId(row['id_penjualan']);
        rows.add(row);
      }
      page++;
    } while (page <= pages!);
    if (rows.length != total ||
        rows.map((row) => row['id_penjualan']).toSet().length != rows.length) {
      throw const FormatException('Daftar penjualan berulang.');
    }
    return List.unmodifiable(rows.map(SaleRecord.fromJson));
  }

  Future<SaleRecord> getSale(String id) async {
    saleId(id);
    final record = _record(await _api.get('penjualan/$id'));
    if (record.id != id) {
      throw const FormatException('Respons penjualan tidak sesuai target.');
    }
    return record;
  }

  Future<SaleRecord> createSale(SalesDraft draft, String key) async {
    final record = _record(
      await _api.post(
        'penjualan',
        body: draft.toJson(),
        headers: {'Idempotency-Key': key},
      ),
    );
    if (record.version == null) {
      throw const FormatException('Respons penjualan tidak valid.');
    }
    _matchesDraft(record, draft);
    return record;
  }

  Future<SaleRecord> updateSale(
    String id,
    SalesDraft draft,
    String expectedVersion,
    String key,
  ) async {
    saleId(id);
    saleId(expectedVersion);
    final record = _record(
      await _api.patch(
        'penjualan/$id',
        body: {...draft.toJson(), 'expected_version': expectedVersion},
        headers: {'Idempotency-Key': key},
      ),
    );
    if (record.id != id ||
        record.version == null ||
        BigInt.parse(record.version!) <= BigInt.parse(expectedVersion)) {
      throw const FormatException('Respons pembaruan penjualan tidak valid.');
    }
    _matchesDraft(record, draft);
    return record;
  }

  Future<SaleRecord> updateSaleHeader(
    String id,
    SalesHeaderDraft draft,
    String expectedVersion,
    String key,
  ) async {
    saleId(id);
    saleId(expectedVersion);
    final record = _record(
      await _api.patch(
        'penjualan/$id',
        body: draft.toJson(expectedVersion),
        headers: {'Idempotency-Key': key},
      ),
    );
    if (record.id != id ||
        record.version == null ||
        BigInt.parse(record.version!) <= BigInt.parse(expectedVersion)) {
      throw const FormatException('Respons pembaruan penjualan tidak valid.');
    }
    if (record.date != draft.date ||
        record.buyer != draft.buyer.trim() ||
        record.status != draft.status ||
        record.note != draft.note) {
      throw const FormatException('Respons penjualan tidak sesuai isian.');
    }
    return record;
  }

  void _matchesDraft(SaleRecord record, SalesDraft draft) {
    final detail = record.details.length == 1 ? record.details.single : null;
    if (record.date != draft.date ||
        record.buyer != draft.buyer.trim() ||
        record.status != draft.status ||
        record.note != draft.note ||
        detail == null ||
        detail.harvestId != draft.harvestId ||
        detail.quantity.wire != draft.quantityWire ||
        detail.priceWire != draft.priceWire) {
      throw const FormatException('Respons penjualan tidak sesuai isian.');
    }
  }

  SaleRecord _record(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons penjualan tidak valid.');
    }
    return SaleRecord.fromJson(data);
  }
}
