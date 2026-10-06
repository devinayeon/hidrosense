// lib/models/laporan_kerusakan_model.dart

class LaporanKerusakan {
  final String id;
  final String mejaId;
  final String mejaName;
  final String barisId;
  final String barisName;
  final int jumlahRusak;
  final String kategoriKegagalan;
  final DateTime tanggalDitemukan;
  final String? penyebabUtama;
  final String? fotoUrl;

  const LaporanKerusakan({
    required this.id,
    required this.mejaId,
    required this.mejaName,
    required this.barisId,
    required this.barisName,
    required this.jumlahRusak,
    required this.kategoriKegagalan,
    required this.tanggalDitemukan,
    this.penyebabUtama,
    this.fotoUrl,
  });
}
