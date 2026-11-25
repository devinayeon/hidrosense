/// Persisted API data for the medicine master (`/api/v1/obat`).
///
/// Only the fields the mobile UI needs are kept: identity, display name, and
/// active flag. A medicine is linked to an inventory item through `id_obat`.
final class ObatRecord {
  const ObatRecord({
    required this.id,
    required this.name,
    required this.active,
  });

  final String id;
  final String name;
  final bool active;

  factory ObatRecord.fromJson(Map<String, dynamic> json) {
    if (json['id_obat'] is! String ||
        json['nama_obat'] is! String ||
        (json['status_aktif'] != 0 && json['status_aktif'] != 1)) {
      throw const FormatException('Data obat tidak valid.');
    }
    return ObatRecord(
      id: json['id_obat'] as String,
      name: json['nama_obat'] as String,
      active: (json['status_aktif'] as int) == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_obat': id,
    'nama_obat': name,
    'status_aktif': active ? 1 : 0,
  };
}
