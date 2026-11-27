/// Satu obat bawaan dari katalog pengetahuan (`GET /api/v1/obat-katalog`).
///
/// Katalog ini terpisah dari master `obat` milik pengguna. Barang jenis Obat
/// ditautkan ke katalog lewat `id_katalog`, dan nama barangnya diturunkan server
/// dari `bahan_aktif` (dikirim di sini sebagai [name]).
final class ObatKatalogRecord {
  const ObatKatalogRecord({
    required this.id,
    required this.name,
    required this.jenis,
  });

  final String id;
  final String name;
  final String jenis;

  factory ObatKatalogRecord.fromJson(Map<String, dynamic> json) {
    if (json['id_katalog'] is! String || json['nama'] is! String) {
      throw const FormatException('Data katalog obat tidak valid.');
    }
    return ObatKatalogRecord(
      id: json['id_katalog'] as String,
      name: json['nama'] as String,
      jenis: json['jenis'] is String ? json['jenis'] as String : '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id_katalog': id,
    'nama': name,
    'jenis': jenis,
  };
}
