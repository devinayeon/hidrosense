import '../../core/uuid.dart';
import '../models/nursery_record.dart';
import '../models/transfer_record.dart';
import '../services/api_client.dart';

class NurseryRepository {
  NurseryRepository(this._api);
  final ApiClient _api;
  String get serverOrigin => _api.serverOrigin;

  Future<List<SowingRecord>> listSowings() async {
    final records = <SowingRecord>[];
    final ids = <String>{};
    var page = 1;
    int? total;
    var totalPages = 1;
    do {
      final response = await _api.get(
        'penyemaian',
        query: {'page': '$page', 'limit': '50'},
      );
      final data = response['data'];
      final meta = response['meta'];
      if (data is! List ||
          meta is! Map ||
          meta['page'] != page ||
          meta['total'] is! int ||
          meta['total_pages'] is! int ||
          (meta['total'] as int) < 0 ||
          (meta['total_pages'] as int) < 0 ||
          (total != null && meta['total'] != total)) {
        throw const FormatException('Daftar penyemaian tidak lengkap.');
      }
      total = meta['total'];
      totalPages = meta['total_pages'];
      for (final row in data) {
        final item = SowingRecord.fromJson(row as Map<String, dynamic>);
        if (!ids.add(item.id)) {
          throw const FormatException('Batch penyemaian duplikat.');
        }
        records.add(item);
      }
      page++;
    } while (page <= totalPages);
    if (records.length != total) {
      throw const FormatException('Daftar penyemaian tidak lengkap.');
    }
    return records;
  }

  Future<TransferRecord> transferSowing({
    required String idempotencyKey,
    required String sowingId,
    required String tableId,
    required String transferDate,
    required int plantCount,
    String? note,
  }) async {
    final response = await _api.post(
      'pemindahan',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'id_penyemaian': sowingId,
        'id_meja': tableId,
        'tanggal_pemindahan': transferDate,
        'jumlah_tanaman': plantCount,
        if (note != null && note.isNotEmpty) 'keterangan': note,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons pemindahan tidak valid.');
    }
    final receipt = TransferRecord.fromJson(data);
    if (receipt.sowingId != sowingId ||
        receipt.tableId != tableId ||
        receipt.transferDate != transferDate ||
        receipt.plantCount != plantCount) {
      throw const FormatException(
        'Respons pemindahan tidak sesuai permintaan.',
      );
    }
    return receipt;
  }

  Future<SowingRecord> getSowing(String id) async {
    final response = await _api.get('penyemaian/$id');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Detail penyemaian tidak valid.');
    }
    return SowingRecord.fromJson(data);
  }

  Future<SowingRecord> createSowing({
    required String sowingDate,
    required int seedCount,
    String? note,
    required List<Map<String, dynamic>> materials,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? generateUuidV4();
    final response = await _api.post(
      'penyemaian',
      headers: {'Idempotency-Key': key},
      body: {
        'tanggal_semai': sowingDate,
        'jumlah_benih': seedCount,
        if (note != null && note.isNotEmpty) 'keterangan': note,
        'materials': materials,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gagal membuat batch penyemaian.');
    }
    return SowingRecord.fromJson(data);
  }

  Future<SowingRecord> updateSowing(
    String id, {
    int? seedCount,
    String? status,
    String? note,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{};
    if (seedCount != null) body['jumlah_benih'] = seedCount;
    if (status != null) body['status_penyemaian'] = status;
    if (note != null) body['keterangan'] = note;

    final response = await _api.patch(
      'penyemaian/$id',
      body: body,
      headers: {'Idempotency-Key': idempotencyKey ?? generateUuidV4()},
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gagal memperbarui penyemaian.');
    }
    return SowingRecord.fromJson(data);
  }
}
