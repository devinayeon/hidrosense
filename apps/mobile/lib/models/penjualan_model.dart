enum StatusPenjualan { lunas, belumLunas }

class BatchPanen {
  final String id;
  final String nama;
  final double stokTersedia; // Dalam Kg
  final String? tanggalPanen;

  const BatchPanen({
    required this.id,
    required this.nama,
    required this.stokTersedia,
    this.tanggalPanen,
  });

  BatchPanen copyWith({
    String? nama,
    double? stokTersedia,
    String? tanggalPanen,
  }) {
    return BatchPanen(
      id: id,
      nama: nama ?? this.nama,
      stokTersedia: stokTersedia ?? this.stokTersedia,
      tanggalPanen: tanggalPanen ?? this.tanggalPanen,
    );
  }
}

class PenjualanLine {
  final String idPanen;
  final String tanggalPanen;
  final double jumlahKg;
  final double hargaPerKg;
  final String hargaPerKgWire;
  final double totalHarga;
  final double? beratLayak;

  const PenjualanLine({
    required this.idPanen,
    required this.tanggalPanen,
    required this.jumlahKg,
    required this.hargaPerKg,
    required this.hargaPerKgWire,
    required this.totalHarga,
    this.beratLayak,
  });
}

class PenjualanItem {
  final String id;
  final String pembeli;
  final String tanggal;
  final String? tanggalIso;
  final String kuantitas; // Contoh: "50 Kg"
  final double totalHarga; // Contoh: 1000000
  final StatusPenjualan status;
  final String? catatan;
  final String? batchPanenId;
  final String? version;
  final List<PenjualanLine> details;

  const PenjualanItem({
    required this.id,
    required this.pembeli,
    required this.tanggal,
    this.tanggalIso,
    required this.kuantitas,
    required this.totalHarga,
    required this.status,
    this.catatan,
    this.batchPanenId,
    this.version,
    this.details = const [],
  });

  bool get isLunas => status == StatusPenjualan.lunas;

  DateTime? get tanggalTransaksi {
    final value = tanggalIso;
    return value == null ? null : DateTime.tryParse(value);
  }

  bool get canEdit => version != null && tanggalIso != null;

  bool get canEditDetails => canEdit && details.length == 1;

  PenjualanItem copyWith({
    String? id,
    String? pembeli,
    String? tanggal,
    String? tanggalIso,
    String? kuantitas,
    double? totalHarga,
    StatusPenjualan? status,
    String? catatan,
    String? batchPanenId,
    String? version,
    List<PenjualanLine>? details,
  }) {
    return PenjualanItem(
      id: id ?? this.id,
      pembeli: pembeli ?? this.pembeli,
      tanggal: tanggal ?? this.tanggal,
      tanggalIso: tanggalIso ?? this.tanggalIso,
      kuantitas: kuantitas ?? this.kuantitas,
      totalHarga: totalHarga ?? this.totalHarga,
      status: status ?? this.status,
      catatan: catatan ?? this.catatan,
      batchPanenId: batchPanenId ?? this.batchPanenId,
      version: version ?? this.version,
      details: details ?? this.details,
    );
  }
}
