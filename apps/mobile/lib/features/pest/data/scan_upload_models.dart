part of 'pest_models.dart';

/// Model unggah Cloudinary dan pindaian. Bagian dari pest_models.dart supaya berbagi pembaca JSON.
class CloudinarySignature {
  const CloudinarySignature({
    required this.cloudName,
    required this.apiKey,
    required this.timestamp,
    required this.folder,
    required this.signature,
    required this.uploadUrl,
  });

  factory CloudinarySignature.fromJson(Object? json) {
    final m = _map(json, 'Tanda tangan unggahan');
    final ts = m['timestamp'];
    if (ts is! int) throw const FormatException('Field timestamp tidak valid.');
    return CloudinarySignature(
      cloudName: _str(m, 'cloud_name'),
      apiKey: _str(m, 'api_key'),
      timestamp: ts,
      folder: _str(m, 'folder'),
      signature: _str(m, 'signature'),
      uploadUrl: _str(m, 'upload_url'),
    );
  }

  final String cloudName;
  final String apiKey;
  final int timestamp;
  final String folder;
  final String signature;
  final String uploadUrl;
}

class UploadedPhoto {
  const UploadedPhoto({required this.secureUrl, required this.publicId});

  final String secureUrl;
  final String publicId;
}

/// Satu hama pada satu foto, dikirim ke `POST /pindaian`.
class ScanFindingDraft {
  const ScanFindingDraft({
    required this.pest,
    required this.count,
    required this.maxConfidence,
  });

  final PestKind pest;
  final int count;
  final double maxConfidence;

  Map<String, dynamic> toJson() => {
    'hama': pest.apiCode,
    'jumlah': count,
    'confidence_maks': double.parse(maxConfidence.toStringAsFixed(4)),
  };
}

/// Satu hama pada satu foto yang sudah tersimpan (`GET /pindaian`).
class ScanDetection {
  const ScanDetection({required this.pest, required this.count, this.maxConfidence});

  factory ScanDetection.fromJson(Object? json) {
    final m = _map(json, 'Deteksi');
    final pest = PestKind.fromApiCode(_str(m, 'hama'));
    if (pest == null) throw FormatException('Hama tidak dikenal: ${m['hama']}');
    final jumlah = m['jumlah'];
    if (jumlah is! int) throw const FormatException('Field jumlah tidak valid.');
    final confidence = m['confidence_maks'];
    if (confidence != null && confidence is! num) {
      throw const FormatException('Field confidence_maks tidak valid.');
    }
    return ScanDetection(
      pest: pest,
      count: jumlah,
      maxConfidence: (confidence as num?)?.toDouble(),
    );
  }

  final PestKind pest;
  final int count;

  /// Keyakinan tertinggi model untuk hama ini (0–1); null bila server tidak menyimpannya.
  final double? maxConfidence;

  /// `87` untuk 0.87, null bila tidak ada.
  int? get confidencePercent =>
      maxConfidence == null ? null : (maxConfidence! * 100).round();
}

/// Satu foto hasil deteksi yang sudah tersimpan di server.
class PestScanRecord {
  const PestScanRecord({
    required this.id,
    required this.transferId,
    required this.tableId,
    required this.detectedAt,
    this.detections = const [],
  });

  factory PestScanRecord.fromJson(Object? json) {
    final m = _map(json, 'Pindaian');
    final tanggal = DateTime.tryParse(_str(m, 'tanggal_deteksi'));
    if (tanggal == null) throw const FormatException('Tanggal deteksi tidak valid.');
    final rows = m['deteksi'];
    if (rows is! List) throw const FormatException('Field deteksi tidak valid.');
    return PestScanRecord(
      id: _str(m, 'id_hasil_deteksi'),
      transferId: _str(m, 'id_pemindahan'),
      tableId: _str(m, 'id_meja'),
      detectedAt: tanggal,
      detections: rows.map(ScanDetection.fromJson).toList(growable: false),
    );
  }

  final String id;
  final String transferId;
  final String tableId;
  final DateTime detectedAt;

  /// Kosong berarti tidak ada hama pada foto itu.
  final List<ScanDetection> detections;

  bool get adaHama => detections.isNotEmpty;
}

class ScanPage {
  const ScanPage({required this.items, required this.page, required this.totalPages});

  final List<PestScanRecord> items;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}
