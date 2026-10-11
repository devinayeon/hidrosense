enum StatusPenjualan { lunas, belumLunas }

class BatchPanen {
  final String id;
  final String nama;
  final double stokTersedia; // Dalam Kg

  const BatchPanen({
    required this.id,
    required this.nama,
    required this.stokTersedia,
  });
}

class PenjualanItem {
  final String id;
  final String pembeli;
  final String tanggal;
  final String kuantitas; // Contoh: "50 Kg Selada"
  final double totalHarga; // Contoh: 1000000
  final StatusPenjualan status;
  final String? catatan;
  final String? batchPanenId;

  const PenjualanItem({
    required this.id,
    required this.pembeli,
    required this.tanggal,
    required this.kuantitas,
    required this.totalHarga,
    required this.status,
    this.catatan,
    this.batchPanenId,
  });

  bool get isLunas => status == StatusPenjualan.lunas;

  PenjualanItem copyWith({
    String? id,
    String? pembeli,
    String? tanggal,
    String? kuantitas,
    double? totalHarga,
    StatusPenjualan? status,
    String? catatan,
    String? batchPanenId,
  }) {
    return PenjualanItem(
      id: id ?? this.id,
      pembeli: pembeli ?? this.pembeli,
      tanggal: tanggal ?? this.tanggal,
      kuantitas: kuantitas ?? this.kuantitas,
      totalHarga: totalHarga ?? this.totalHarga,
      status: status ?? this.status,
      catatan: catatan ?? this.catatan,
      batchPanenId: batchPanenId ?? this.batchPanenId,
    );
  }
}
