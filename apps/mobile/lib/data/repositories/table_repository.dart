import '../models/table_record.dart';
import '../services/api_client.dart';

class TableRepository {
  TableRepository(this._api);
  final ApiClient _api;

  Future<List<TableRecord>> fetchTables({
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    final response = await _api.get(
      'meja-tanam',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status_meja': status,
      },
    );
    final data = response['data'];
    if (data is! List) {
      throw const FormatException('Daftar meja tanam tidak valid.');
    }
    return data
        .map((item) => TableRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TableRecord> getTable(String id) async {
    final response = await _api.get('meja-tanam/$id');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Detail meja tanam tidak valid.');
    }
    return TableRecord.fromJson(data);
  }

  Future<TableRecord> createTable({
    required String code,
    required int holeCount,
    String? status,
    String? notes,
  }) async {
    final response = await _api.post(
      'meja-tanam',
      body: {
        'kode_meja': code,
        'jumlah_lubang': holeCount,
        if (status != null && status.isNotEmpty) 'status_meja': status,
        if (notes != null && notes.isNotEmpty) 'keterangan': notes,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gagal menambahkan meja tanam.');
    }
    return TableRecord.fromJson(data);
  }

  Future<TableRecord> updateTable(
    String id, {
    String? code,
    int? holeCount,
    String? status,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (code != null && code.isNotEmpty) body['kode_meja'] = code;
    if (holeCount != null) body['jumlah_lubang'] = holeCount;
    if (status != null && status.isNotEmpty) body['status_meja'] = status;
    if (notes != null) body['keterangan'] = notes;

    final response = await _api.patch('meja-tanam/$id', body: body);
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gagal memperbarui meja tanam.');
    }
    return TableRecord.fromJson(data);
  }
}
