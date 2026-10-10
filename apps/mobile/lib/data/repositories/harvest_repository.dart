import '../models/harvest_record.dart';
import '../models/transfer_record.dart';
import '../services/api_client.dart';

class HarvestRepository {
  HarvestRepository(this._api);
  final ApiClient _api;
  String get serverOrigin => _api.serverOrigin;
  Future<List<HarvestRecord>> listHarvests() async => List.unmodifiable(
    (await _list('panen', 'id_panen')).map(HarvestRecord.fromJson),
  );
  Future<List<TransferRecord>> listTransfers() async => List.unmodifiable(
    (await _list('pemindahan', 'id_pemindahan')).map(TransferRecord.fromJson),
  );
  Future<HarvestRecord> getHarvest(String id) async {
    harvestId(id);
    final record = _record(await _api.get('panen/$id'));
    if (record.id != id) {
      throw const FormatException('Respons panen tidak sesuai target.');
    }
    return record;
  }

  Future<HarvestRecord> write(
    String target,
    Map<String, dynamic> body,
    String key,
  ) async {
    final response = target == 'create'
        ? await _api.post(
            'panen',
            body: body,
            headers: {'Idempotency-Key': key},
          )
        : await _api.patch(
            'panen/${harvestId(target)}',
            body: body,
            headers: {'Idempotency-Key': key},
          );
    final record = _record(response);
    if (target != 'create' && record.id != target) {
      throw const FormatException('Respons panen tidak sesuai target.');
    }
    if (target == 'create') {
      final rows = body['details'] as List;
      if (record.date != body['tanggal_panen'] ||
          rows.length != record.details.length ||
          rows.any(
            (row) => !record.details.any(
              (d) =>
                  d.transferId == row['id_pemindahan'] &&
                  d.plantCount == row['jumlah_tanaman'] &&
                  d.total?.wire == row['berat_total'] &&
                  d.reject?.wire == row['berat_reject'],
            ),
          )) {
        throw const FormatException('Respons panen tidak sesuai isian.');
      }
    }
    if (record.version == null || record.note != body['keterangan']) {
      throw const FormatException('Respons pembaruan panen tidak valid.');
    }
    if (target != 'create') {
      if (BigInt.parse(record.version!) !=
              BigInt.parse(body['expected_version'] as String) + BigInt.one ||
          (body['details'] as List?)?.any(
                (row) => !record.details.any(
                  (d) =>
                      d.id == row['id_detail_panen'] &&
                      d.total?.wire == row['berat_total'] &&
                      d.reject?.wire == row['berat_reject'],
                ),
              ) ==
              true) {
        throw const FormatException('Respons koreksi tidak sesuai isian.');
      }
    }
    return record;
  }

  HarvestRecord _record(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons panen tidak valid.');
    }
    return HarvestRecord.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> _list(String path, String idField) async {
    final rows = <Map<String, dynamic>>[];
    int? total, pages;
    var page = 1;
    do {
      final response = await _api.get(
        path,
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
        throw const FormatException(
          'Halaman panen atau batch berubah. Muat ulang.',
        );
      }
      total = meta['total'];
      pages = meta['total_pages'];
      final expected = total! == 0
          ? 0
          : page < pages!
          ? 100
          : total - (page - 1) * 100;
      if (data.length != expected) {
        throw const FormatException('Daftar panen atau batch tidak lengkap.');
      }
      for (final row in data) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException('Daftar panen atau batch tidak valid.');
        }
        harvestId(row[idField]);
        rows.add(row);
      }
      page++;
    } while (page <= pages!);
    if (rows.length != total ||
        rows.map((r) => r[idField]).toSet().length != rows.length) {
      throw const FormatException('Daftar panen atau batch berulang.');
    }
    return rows;
  }
}
