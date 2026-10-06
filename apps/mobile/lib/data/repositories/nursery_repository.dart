import '../models/nursery_record.dart';
import '../services/api_client.dart';

class NurseryRepository {
  NurseryRepository(this._api);
  final ApiClient _api;

  Future<List<SowingRecord>> listSowings({
    int page = 1,
    int limit = 50,
    String? status,
    bool? readyOnly,
  }) async {
    final response = await _api.get(
      'penyemaian',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null) 'status_penyemaian': status,
        if (readyOnly == true) 'siap_pindah': '1',
      },
    );
    final data = response['data'];
    if (data is! List) throw const FormatException('Daftar penyemaian tidak valid.');
    return data.map((item) => SowingRecord.fromJson(item as Map<String, dynamic>)).toList();
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
  }) async {
    final response = await _api.post(
      'penyemaian',
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
