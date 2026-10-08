import '../../core/uuid.dart';
import '../models/nursery_record.dart';
import '../services/api_client.dart';

class NurseryRepository {
  NurseryRepository(this._api);
  final ApiClient _api;

  Future<void> transferSowing({
    required String idempotencyKey,
    required String sowingId,
    required String tableId,
    required String transferDate,
    required int plantCount,
    String? note,
  }) async {
    await _api.post(
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
  }

  Future<List<SowingRecord>> listSowings({
    int page = 1,
    int limit = 50,
    String? status,
    bool? readyOnly,
  }) async {
    final query = <String, String>{'page': '$page', 'limit': '$limit'};
    if (status != null) query['status_penyemaian'] = status;
    if (readyOnly == true) query['siap_pindah'] = '1';

    final response = await _api.get('penyemaian', query: query);
    final data = response['data'];
    if (data is! List) {
      throw const FormatException('Daftar penyemaian tidak valid.');
    }
    return data
        .map((item) => SowingRecord.fromJson(item as Map<String, dynamic>))
        .toList();
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
  }) async {
    final body = <String, dynamic>{};
    if (seedCount != null) body['jumlah_benih'] = seedCount;
    if (status != null) body['status_penyemaian'] = status;
    if (note != null) body['keterangan'] = note;

    final response = await _api.patch('penyemaian/$id', body: body);
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gagal memperbarui penyemaian.');
    }
    return SowingRecord.fromJson(data);
  }
}
