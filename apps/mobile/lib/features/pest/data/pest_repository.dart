import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/uuid.dart';
import '../../../data/services/api_client.dart';
import '../domain/pest_summary.dart';
import 'pest_models.dart';

/// Akses API pindaian hama, rekomendasi rotasi obat, dan unggah foto ke Cloudinary.
///
/// Setiap penulisan membawa `Idempotency-Key`. Pemanggil yang mengulang setelah hasil tidak pasti
/// harus memakai kunci yang sama ([idempotencyKey]); tanpa itu kunci baru dibuat per panggilan.
class PestRepository {
  PestRepository(this._api, {http.Client? uploadClient})
    : _uploadClient = uploadClient ?? http.Client(),
      _ownsUploadClient = uploadClient == null;

  final ApiClient _api;
  final http.Client _uploadClient;
  final bool _ownsUploadClient;

  void close() {
    if (_ownsUploadClient) _uploadClient.close();
  }

  Map<String, String> _key(String? key) => {
    'Idempotency-Key': key ?? generateUuidV4(),
  };

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons server tidak valid.');
    }
    return data;
  }

  Future<CloudinarySignature> signUpload() async =>
      CloudinarySignature.fromJson(
        _data(await _api.post('unggahan/tanda-tangan')),
      );

  /// Unggah langsung ke Cloudinary dengan tanda tangan dari backend. Hanya alamat Cloudinary
  /// https yang diterima sebagai hasil, supaya jawaban janggal tidak sampai ke database.
  Future<UploadedPhoto> uploadPhoto(
    Uint8List bytes,
    CloudinarySignature sig, {
    String filename = 'pindai.jpg',
  }) async {
    final uri = Uri.parse(sig.uploadUrl);
    if (uri.scheme != 'https' || uri.host != 'api.cloudinary.com') {
      throw const FormatException('Alamat unggah bukan Cloudinary.');
    }
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = sig.apiKey
      ..fields['timestamp'] = '${sig.timestamp}'
      ..fields['folder'] = sig.folder
      ..fields['signature'] = sig.signature
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    final streamed = await _uploadClient
        .send(request)
        .timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'UPLOAD_FAILED',
        'Unggah foto gagal (${response.statusCode}).',
      );
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Respons Cloudinary tidak valid.');
    }
    final url = body['secure_url'];
    final publicId = body['public_id'];
    if (url is! String || publicId is! String) {
      throw const FormatException('Respons Cloudinary tidak lengkap.');
    }
    final photo = Uri.parse(url);
    if (photo.scheme != 'https' || photo.host != 'res.cloudinary.com') {
      throw const FormatException('Alamat foto bukan dari Cloudinary.');
    }
    return UploadedPhoto(secureUrl: url, publicId: publicId);
  }

  /// Simpan hasil pindai. Daftar kosong berarti tidak ada hama pada foto itu.
  Future<String> saveScan({
    required String transferId,
    required UploadedPhoto photo,
    required String modelVersion,
    required List<ScanFindingDraft> findings,
    String? idempotencyKey,
  }) async {
    final response = await _api.post(
      'pindaian',
      headers: _key(idempotencyKey),
      body: {
        'id_pemindahan': transferId,
        'gambar': photo.secureUrl,
        'cloudinary_public_id': photo.publicId,
        'versi_model': modelVersion,
        'deteksi': findings.map((f) => f.toJson()).toList(),
      },
    );
    final id = _data(response)['id_hasil_deteksi'];
    if (id is! String) {
      throw const FormatException('Respons pindaian tidak valid.');
    }
    return id;
  }

  Future<PestRecommendation> createRecommendation({
    required String tableId,
    required PestKind pest,
    required PestSeverity severity,
    String? scanId,
    String? idempotencyKey,
  }) async {
    final response = await _api.post(
      'rekomendasi-obat',
      headers: _key(idempotencyKey),
      body: {
        'id_meja': tableId,
        'hama': pest.apiCode,
        'tingkat': severity.apiCode,
        'id_hasil_deteksi': ?scanId,
      },
    );
    final rec = PestRecommendation.fromJson(_data(response));
    if (rec.tableId != tableId || rec.pest != pest) {
      throw const FormatException(
        'Respons rekomendasi tidak sesuai permintaan.',
      );
    }
    return rec;
  }

  Future<RecommendationPage> list({
    RecommendationStatus? status,
    String? tableId,
    PestKind? pest,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get(
      'rekomendasi-obat',
      query: {
        'page': '$page',
        'limit': '$limit',
        'status': ?status?.apiCode,
        'id_meja': ?tableId,
        'hama': ?pest?.apiCode,
      },
    );
    final rows = response['data'];
    final meta = response['meta'];
    if (rows is! List || meta is! Map<String, dynamic>) {
      throw const FormatException('Respons daftar rekomendasi tidak valid.');
    }
    final items = rows.map(PestRecommendation.fromJson).toList(growable: false);
    if (status != null && items.any((r) => r.status != status)) {
      throw const FormatException(
        'Server mengembalikan status yang tidak diminta.',
      );
    }
    return RecommendationPage(
      items: items,
      page: (meta['page'] as num).toInt(),
      totalPages: (meta['total_pages'] as num).toInt(),
    );
  }

  /// Daftar foto deteksi tersimpan, terbaru dulu. `id_pemindahan` menyaring satu batch tanam.
  Future<ScanPage> listScans({String? transferId, int page = 1, int limit = 20}) async {
    final response = await _api.get(
      'pindaian',
      query: {
        'page': '$page',
        'limit': '$limit',
        'id_pemindahan': ?transferId,
      },
    );
    final rows = response['data'];
    final meta = response['meta'];
    if (rows is! List || meta is! Map<String, dynamic>) {
      throw const FormatException('Respons daftar pindaian tidak valid.');
    }
    return ScanPage(
      items: rows.map(PestScanRecord.fromJson).toList(growable: false),
      page: (meta['page'] as num).toInt(),
      totalPages: (meta['total_pages'] as num).toInt(),
    );
  }

  /// Terima = obat dipakai. [appliedOn] YYYY-MM-DD, bawaan server: hari ini.
  Future<PestRecommendation> accept(
    String id, {
    String? appliedOn,
    String? note,
    List<StockLineDraft> materials = const [],
    String? idempotencyKey,
  }) async {
    final response = await _api.post(
      'rekomendasi-obat/$id/terima',
      headers: _key(idempotencyKey),
      body: {
        'tanggal_aplikasi': ?appliedOn,
        if (note != null && note.trim().isNotEmpty) 'catatan': note.trim(),
        if (materials.isNotEmpty)
          'bahan': materials.map((m) => m.toJson()).toList(),
      },
    );
    return _decided(response, id, RecommendationStatus.diterima);
  }

  Future<PestRecommendation> reject(
    String id,
    RejectReason reason, {
    String? note,
    String? idempotencyKey,
  }) async {
    final trimmed = note?.trim();
    if (reason.requiresNote && (trimmed == null || trimmed.isEmpty)) {
      throw ArgumentError('Catatan wajib diisi untuk alasan "lainnya".');
    }
    final response = await _api.post(
      'rekomendasi-obat/$id/tolak',
      headers: _key(idempotencyKey),
      body: {
        'alasan': reason.apiCode,
        if (trimmed != null && trimmed.isNotEmpty) 'catatan': trimmed,
      },
    );
    return _decided(response, id, RecommendationStatus.ditolak);
  }

  PestRecommendation _decided(
    Map<String, dynamic> response,
    String id,
    RecommendationStatus expected,
  ) {
    final rec = PestRecommendation.fromJson(_data(response));
    if (rec.id != id || rec.status != expected) {
      throw const FormatException('Respons keputusan tidak sesuai.');
    }
    return rec;
  }
}
