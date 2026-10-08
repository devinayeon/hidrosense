class DamageRecord {
  const DamageRecord({
    required this.id,
    required this.transferId,
    required this.date,
    required this.plantCount,
    required this.category,
    this.note,
    this.publicId,
    this.version,
  });

  final String id, transferId, date, category;
  final int plantCount;
  final String? note, publicId, version;

  factory DamageRecord.fromJson(Map<String, dynamic> json) {
    for (final field in ['id_kerusakan', 'id_pemindahan']) {
      if (json[field] is! String ||
          !RegExp(r'^[1-9][0-9]*$').hasMatch(json[field])) {
        throw const FormatException('Identitas laporan tidak valid.');
      }
    }
    if (json['tanggal_kejadian'] is! String ||
        DateTime.tryParse(json['tanggal_kejadian']) == null ||
        json['jumlah_tanaman'] is! int ||
        json['jumlah_tanaman'] <= 0 ||
        json['jenis_kerusakan'] is! String ||
        (json['keterangan'] != null && json['keterangan'] is! String) ||
        (json['public_id'] != null && json['public_id'] is! String) ||
        (json['version'] != null && json['version'] is! String)) {
      throw const FormatException('Data laporan kerusakan tidak valid.');
    }
    return DamageRecord(
      id: json['id_kerusakan'],
      transferId: json['id_pemindahan'],
      date: json['tanggal_kejadian'],
      plantCount: json['jumlah_tanaman'],
      category: json['jenis_kerusakan'],
      note: json['keterangan'],
      publicId: json['public_id'],
      version: json['version'],
    );
  }
}

class DamageDraft {
  const DamageDraft({
    required this.transferId,
    required this.date,
    required this.plantCount,
    required this.category,
    this.note,
  });
  final String transferId, date, category;
  final int plantCount;
  final String? note;

  Map<String, dynamic> toJson() => {
    'id_pemindahan': transferId,
    'tanggal_kejadian': date,
    'jumlah_tanaman': plantCount,
    'jenis_kerusakan': category.trim(),
    'keterangan': note == null || note!.trim().isEmpty ? null : note!.trim(),
  };
}
