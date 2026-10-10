import '../../core/uuid.dart';
import '../models/table_record.dart';
import '../services/api_client.dart';

class TableRepository {
  TableRepository(this._api);
  final ApiClient _api;
  static const _omittedNotes = Object();
  String get serverOrigin => _api.serverOrigin;

  Future<List<TableRecord>> fetchTables({String? status}) async {
    final records = <TableRecord>[];
    final ids = <String>{};
    var page = 1;
    var totalPages = 1;
    int? total;
    do {
      final response = await _api.get(
        'meja-tanam',
        query: {
          'page': '$page',
          'limit': '50',
          if (status != null && status.isNotEmpty) 'status_meja': status,
        },
      );
      final data = response['data'];
      final meta = response['meta'];
      if (data is! List ||
          meta is! Map ||
          meta['limit'] != 50 ||
          meta['page'] is! int ||
          meta['page'] != page ||
          meta['total_pages'] is! int ||
          meta['total_pages'] < 0 ||
          meta['total'] is! int ||
          meta['total'] < 0 ||
          (total != null && total != meta['total'])) {
        throw const FormatException('Daftar meja tanam tidak valid.');
      }
      total = meta['total'];
      totalPages = meta['total_pages'];
      if (totalPages != (total! / 50).ceil() ||
          data.length > 50 ||
          (page < totalPages && data.length != 50)) {
        throw const FormatException('Halaman meja tanam tidak lengkap.');
      }
      for (final row in data) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException('Data meja tanam tidak valid.');
        }
        final record = TableRecord.fromJson(row);
        if (!ids.add(record.id)) {
          throw const FormatException('Meja tanam duplikat.');
        }
        records.add(record);
      }
      page++;
    } while (page <= totalPages);
    if (records.length != total) {
      throw const FormatException('Daftar meja tanam tidak lengkap.');
    }
    return List.unmodifiable(records);
  }

  Future<TableRecord> getTable(String id) async {
    final response = await _api.get('meja-tanam/$id');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Detail meja tanam tidak valid.');
    }
    final record = TableRecord.fromJson(data);
    if (record.id != id) {
      throw const FormatException('Respons meja tidak sesuai target.');
    }
    return record;
  }

  Future<TableRecord> createTable({
    required String code,
    required int holeCount,
    String? status,
    String? notes,
    String? idempotencyKey,
  }) async {
    final response = await _api.post(
      'meja-tanam',
      headers: {'Idempotency-Key': idempotencyKey ?? generateUuidV4()},
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
    Object? notes = _omittedNotes,
    String? idempotencyKey,
  }) async {
    if (!identical(notes, _omittedNotes) && notes != null && notes is! String) {
      throw ArgumentError.value(notes, 'notes', 'Must be a string or null.');
    }
    final body = <String, dynamic>{};
    if (code != null && code.isNotEmpty) body['kode_meja'] = code;
    if (holeCount != null) body['jumlah_lubang'] = holeCount;
    if (status != null && status.isNotEmpty) body['status_meja'] = status;
    if (!identical(notes, _omittedNotes)) body['keterangan'] = notes;

    final response = await _api.patch(
      'meja-tanam/$id',
      body: body,
      headers: {'Idempotency-Key': idempotencyKey ?? generateUuidV4()},
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gagal memperbarui meja tanam.');
    }
    final record = TableRecord.fromJson(data);
    if (record.id != id) {
      throw const FormatException('Respons meja tidak sesuai target.');
    }
    return record;
  }
}
