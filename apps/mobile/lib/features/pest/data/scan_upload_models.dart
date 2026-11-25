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
