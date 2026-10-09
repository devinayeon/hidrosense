class SowingMaterialLine {
  const SowingMaterialLine({
    required this.inventoryId,
    required this.amount,
    required this.unit,
  });

  final String inventoryId;
  final String amount;
  final String unit;

  factory SowingMaterialLine.fromJson(Map<String, dynamic> json) {
    if (json['id_inventaris'] is! String ||
        json['jumlah'] is! String ||
        json['satuan'] is! String) {
      throw const FormatException('Material penyemaian tidak valid.');
    }
    return SowingMaterialLine(
      inventoryId: json['id_inventaris'] as String,
      amount: json['jumlah'] as String,
      unit: json['satuan'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_inventaris': inventoryId,
    'jumlah': amount,
    'satuan': unit,
  };
}

class SowingRecord {
  const SowingRecord({
    required this.id,
    required this.userId,
    required this.sowingDate,
    required this.seedCount,
    int? remainingSeedCount,
    required this.status,
    this.note,
    this.ageDays,
    required this.isReadyToMove,
    this.materials = const [],
  }) : remainingSeedCount = remainingSeedCount ?? seedCount;

  final String id;
  final String userId;
  final String sowingDate;
  final int seedCount;
  final int remainingSeedCount;
  final String status; // 'aktif' | 'selesai'
  final String? note;
  final int? ageDays;
  final bool isReadyToMove;
  final List<SowingMaterialLine> materials;

  String get batchName => 'Batch #$id';
  bool get canTransfer =>
      status == 'aktif' && isReadyToMove && remainingSeedCount > 0;
  String get statusLabel => status == 'selesai'
      ? 'Selesai'
      : canTransfer
      ? 'Siap Pindah ($hssText)'
      : 'Semai ($hssText)';
  String get hssText => ageDays != null ? '$ageDays HSS' : '- HSS';
  String get seedCountText => '$remainingSeedCount Butir';

  factory SowingRecord.fromJson(Map<String, dynamic> json) {
    if (json['id_penyemaian'] is! String ||
        json['id_user'] is! String ||
        json['tanggal_semai'] is! String ||
        json['jumlah_benih'] is! num) {
      throw const FormatException('Data penyemaian tidak valid.');
    }

    final rawMaterials =
        json['stok_konsumsi'] ??
        json['consumed_materials'] ??
        json['materials'];
    final matList = rawMaterials is List
        ? rawMaterials
              .map(
                (m) => SowingMaterialLine.fromJson(m as Map<String, dynamic>),
              )
              .toList()
        : const <SowingMaterialLine>[];

    final age = json['usia_hari'] as num?;

    return SowingRecord(
      id: json['id_penyemaian'] as String,
      userId: json['id_user'] as String,
      sowingDate: json['tanggal_semai'] as String,
      seedCount: (json['jumlah_benih'] as num).toInt(),
      remainingSeedCount: (json['sisa_benih'] as num?)?.toInt(),
      status: json['status_penyemaian'] as String? ?? 'aktif',
      note: json['keterangan'] as String?,
      ageDays: age?.toInt(),
      isReadyToMove: json['siap_pindah'] == true,
      materials: matList,
    );
  }
}
