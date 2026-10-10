class TableRecord {
  const TableRecord({
    required this.id,
    required this.code,
    required this.holeCount,
    required this.status,
    this.notes,
    this.activePlants = 0,
    this.availableCapacity = 0,
    this.publicId,
    this.version,
  });

  final String id;
  final String code;
  final int holeCount;
  final String status; // 'tersedia' | 'penuh' | 'pemeliharaan' | 'nonaktif'
  final String? notes;
  final int activePlants;
  final int availableCapacity;
  final String? publicId;
  final String? version;

  String get displayName => 'Meja $code';
  bool get isMaintenance =>
      status == 'pemeliharaan' || status == 'perbaikan' || status == 'rusak';
  bool get isActive => isAvailable || isFull;
  bool get isAvailable => status == 'tersedia';
  bool get isFull => status == 'penuh';
  bool get isInactive => status == 'nonaktif';

  double get occupancyRatio =>
      holeCount > 0 ? (activePlants / holeCount).clamp(0.0, 1.0) : 0.0;

  int get occupancyPercentage => (occupancyRatio * 100).round();

  String get statusLabel {
    switch (status) {
      case 'tersedia':
        return 'Tersedia';
      case 'penuh':
        return 'Penuh';
      case 'pemeliharaan':
        return 'Perawatan';
      case 'nonaktif':
        return 'Nonaktif';
      default:
        return status;
    }
  }

  factory TableRecord.fromJson(Map<String, dynamic> json) {
    if (json['id_meja'] is! String ||
        json['kode_meja'] is! String ||
        json['jumlah_lubang'] is! num) {
      throw const FormatException('Data meja tanam tidak valid.');
    }
    return TableRecord(
      id: json['id_meja'] as String,
      code: json['kode_meja'] as String,
      holeCount: (json['jumlah_lubang'] as num).toInt(),
      status: json['status_meja'] as String? ?? 'tersedia',
      notes: json['keterangan'] as String?,
      activePlants: (json['tanaman_aktif'] as num?)?.toInt() ?? 0,
      availableCapacity:
          (json['kapasitas_tersedia'] as num?)?.toInt() ??
          ((json['jumlah_lubang'] as num).toInt() -
              ((json['tanaman_aktif'] as num?)?.toInt() ?? 0)),
      publicId: json['public_id'] as String?,
      version: json['version'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_meja': id,
    'kode_meja': code,
    'jumlah_lubang': holeCount,
    'status_meja': status,
    'keterangan': notes,
    'tanaman_aktif': activePlants,
    'kapasitas_tersedia': availableCapacity,
    'public_id': publicId,
    'version': version,
  };
}
