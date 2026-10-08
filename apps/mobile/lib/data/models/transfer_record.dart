class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.tableId,
    required this.sowingId,
    required this.transferDate,
    required this.plantCount,
    required this.activePlants,
  });

  final String id, tableId, sowingId, transferDate;
  final int plantCount, activePlants;
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
    );
  }
}
