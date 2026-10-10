import '../models/damage_record.dart';
import '../models/transfer_record.dart';
import '../services/api_client.dart';
import '../../core/uuid.dart';

class DamageRepository {
  DamageRepository(this._api);
  final ApiClient _api;
  String get serverOrigin => _api.serverOrigin;

  Future<List<TransferRecord>> listTransfers(String tableId) async {
    final rows = await _list('pemindahan', {'id_meja': tableId});
    final records = rows.map(TransferRecord.fromJson).toList();
    if (records.any((record) => record.tableId != tableId)) {
      throw const FormatException('Batch berasal dari meja lain.');
    }
    return List.unmodifiable(records);
  }

  Future<List<DamageRecord>> listDamages(String transferId) async {
    final rows = await _list('kerusakan', {'id_pemindahan': transferId});
    final records = rows.map(DamageRecord.fromJson).toList();
    if (records.any((record) => record.transferId != transferId)) {
      throw const FormatException('Laporan berasal dari batch lain.');
    }
    return List.unmodifiable(records);
  }

  Future<DamageRecord> createDamage(
    DamageDraft draft,
    String idempotencyKey,
  ) async {
    final response = await _api.post(
      'kerusakan',
      headers: {'Idempotency-Key': idempotencyKey},
      body: draft.toJson(),
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons laporan kerusakan tidak valid.');
    }
    final record = DamageRecord.fromJson(data);
    if (record.transferId != draft.transferId) {
      throw const FormatException('Respons batch laporan tidak sesuai.');
    }
    return record;
  }

  Future<TransferRecord> updateTransfer(
    String id, {
    String? note,
    String? idempotencyKey,
  }) async {
    final response = await _api.patch(
      'pemindahan/$id',
      headers: {'Idempotency-Key': idempotencyKey ?? generateUuidV4()},
      body: {
        'keterangan': note != null && note.trim().isNotEmpty
            ? note.trim()
            : null,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons pembaruan batch tidak valid.');
    }
    final record = TransferRecord.fromJson(data);
    if (record.id != id) {
      throw const FormatException('Respons batch tidak sesuai target.');
    }
    return record;
  }

  Future<DamageRecord> updateDamage(
    String id, {
    String? date,
    int? plantCount,
    String? category,
    String? note,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{};
    if (date != null && date.isNotEmpty) body['tanggal_kejadian'] = date;
    if (plantCount != null) body['jumlah_tanaman'] = plantCount;
    if (category != null && category.isNotEmpty) {
      body['jenis_kerusakan'] = category.trim();
    }
    body['keterangan'] = note != null && note.trim().isNotEmpty
        ? note.trim()
        : null;

    final response = await _api.patch(
      'kerusakan/$id',
      headers: {'Idempotency-Key': idempotencyKey ?? generateUuidV4()},
      body: body,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons pembaruan kerusakan tidak valid.');
    }
    final record = DamageRecord.fromJson(data);
    if (record.id != id) {
      throw const FormatException('Respons laporan tidak sesuai target.');
    }
    return record;
  }

  Future<List<Map<String, dynamic>>> _list(
    String path,
    Map<String, String> filter,
  ) async {
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    var totalPages = 1;
    int? total;
    do {
      final response = await _api.get(
        path,
        query: {...filter, 'page': '$page', 'limit': '100'},
      );
      final data = response['data'];
      final meta = response['meta'];
      if (data is! List ||
          meta is! Map ||
          meta['page'] != page ||
          meta['total_pages'] is! int ||
          meta['total_pages'] < 0 ||
          meta['total'] is! int ||
          meta['total'] < 0 ||
          (total != null && total != meta['total'])) {
        throw const FormatException('Daftar batch atau laporan tidak valid.');
      }
      total = meta['total'];
      totalPages = meta['total_pages'];
      if (totalPages != (total! / 100).ceil() ||
          data.length > 100 ||
          (page < totalPages && data.length != 100)) {
        throw const FormatException(
          'Halaman batch atau laporan tidak lengkap.',
        );
      }
      for (final row in data) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException('Data batch atau laporan tidak valid.');
        }
        rows.add(row);
      }
      page++;
    } while (page <= totalPages);
    final idField = path == 'pemindahan' ? 'id_pemindahan' : 'id_kerusakan';
    if (rows.length != total ||
        rows.map((row) => row[idField]).toSet().length != rows.length) {
      throw const FormatException('Daftar batch atau laporan tidak lengkap.');
    }
    return rows;
  }
}
