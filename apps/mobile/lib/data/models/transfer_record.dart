class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.tableId,
    required this.sowingId,
    required this.transferDate,
    required this.plantCount,
    required this.activePlants,
    this.sowingDate,
    this.note,
    this.seedlingAgeDays,
    this.estimatedHarvestDate,
    this.hss,
    this.hst,
    this.remainingHarvestDays,
    this.version,
  });

  final String id, tableId, sowingId, transferDate;
  final int plantCount, activePlants;
  final String? sowingDate;
  final String? note;
  final int? seedlingAgeDays;
  final String? estimatedHarvestDate;
  final int? hss;
  final int? hst;
  final int? remainingHarvestDays;
  final String? version;

  String get label => 'Batch #$id • $transferDate';

  factory TransferRecord.fromJson(Map<String, dynamic> json) {
    for (final field in ['id_pemindahan', 'id_meja', 'id_penyemaian']) {
      if (json[field] is! String ||
          !RegExp(r'^[1-9][0-9]*$').hasMatch(json[field])) {
        throw const FormatException('Identitas batch tidak valid.');
      }
    }
    final date = json['tanggal_pemindahan'];
    final count = json['jumlah_tanaman'];
    final active = json['tanaman_aktif'];
    if (date is! String ||
        DateTime.tryParse(date) == null ||
        count is! int ||
        count <= 0 ||
        active is! int ||
        active < 0 ||
        active > count) {
      throw const FormatException('Data batch tidak valid.');
    }
    return TransferRecord(
      id: json['id_pemindahan'],
      tableId: json['id_meja'],
      sowingId: json['id_penyemaian'],
      transferDate: date,
      plantCount: count,
      activePlants: active,
      sowingDate: json['tanggal_semai'] as String?,
      note: json['keterangan'] as String?,
      seedlingAgeDays: (json['umur_semai_hari'] as num?)?.toInt(),
      estimatedHarvestDate: json['estimasi_panen'] as String?,
      hss: (json['hss'] as num?)?.toInt(),
      hst: (json['hst'] as num?)?.toInt(),
      remainingHarvestDays: (json['sisa_hari_panen'] as num?)?.toInt(),
      version: json['version'] as String?,
    );
  }
}
