class JenisInventarisRecord {
  const JenisInventarisRecord({
    required this.id,
    required this.name,
    required this.active,
  });

  final String id;
  final String name;
  final bool active;

  factory JenisInventarisRecord.fromJson(Map<String, dynamic> json) {
    if (json['id_jenis_inventaris'] is! String ||
        json['nama_jenis'] is! String ||
        (json['status_aktif'] != 0 && json['status_aktif'] != 1)) {
      throw const FormatException('Data jenis inventaris tidak valid.');
    }
    return JenisInventarisRecord(
      id: json['id_jenis_inventaris'] as String,
      name: json['nama_jenis'] as String,
      active: (json['status_aktif'] as int) == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_jenis_inventaris': id,
    'nama_jenis': name,
    'status_aktif': active ? 1 : 0,
  };
}
