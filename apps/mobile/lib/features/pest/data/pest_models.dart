import '../domain/pest_summary.dart';

part 'scan_upload_models.dart';

/// Status keputusan pengguna atas satu rekomendasi. Kode sama dengan backend.
enum RecommendationStatus {
  menunggu('menunggu', 'Menunggu'),
  diterima('diterima', 'Diterima'),
  ditolak('ditolak', 'Ditolak');

  const RecommendationStatus(this.apiCode, this.label);

  final String apiCode;
  final String label;

  static RecommendationStatus parse(Object? value) {
    for (final s in RecommendationStatus.values) {
      if (s.apiCode == value) return s;
    }
    throw FormatException('Status rekomendasi tidak dikenal: $value');
  }
}

/// Alasan menolak. Menolak tidak murni "tidak": alasan terstruktur membantu memperbaiki aturan.
enum RejectReason {
  tidakTersedia('tidak_tersedia', 'Obat tidak tersedia'),
  harga('harga', 'Harga terlalu mahal'),
  sudahDitangani('sudah_ditangani', 'Sudah ditangani cara lain'),
  tidakYakinHama('tidak_yakin_hama', 'Tidak yakin dengan hasil deteksi'),
  lainnya('lainnya', 'Alasan lain');

  const RejectReason(this.apiCode, this.label);

  final String apiCode;
  final String label;

  /// Catatan wajib diisi untuk "lainnya".
  bool get requiresNote => this == RejectReason.lainnya;

  static RejectReason? tryParse(Object? value) {
    for (final r in RejectReason.values) {
      if (r.apiCode == value) return r;
    }
    return null;
  }
}

Map<String, dynamic> _map(Object? value, String what) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('$what bukan objek.');
}

String _str(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is String) return v;
  throw FormatException('Field $key tidak valid.');
}

String? _strOrNull(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v == null) return null;
  if (v is String) return v;
  throw FormatException('Field $key tidak valid.');
}

/// Jenis tindakan, urut PHT dari yang paling ringan. Kode sama dengan backend.
enum MedicineKind {
  mekanis('mekanis'),
  hayati('hayati'),
  nabati('nabati'),
  kimia('kimia');

  const MedicineKind(this.apiCode);

  final String apiCode;

  static MedicineKind parse(Object? value) {
    for (final k in MedicineKind.values) {
      if (k.apiCode == value) return k;
    }
    throw FormatException('Jenis obat tidak dikenal: $value');
  }
}

/// Obat dari katalog pengetahuan. Katalog berasal dari riset web dan belum tentu diverifikasi.
class Medicine {
  const Medicine({
    required this.id,
    required this.activeIngredient,
    required this.kind,
    required this.moaCode,
    required this.moaName,
    required this.note,
    required this.preHarvestDays,
    required this.preHarvestSource,
    required this.source,
    required this.verified,
  });

  factory Medicine.fromJson(Object? json) {
    final m = _map(json, 'Obat');
    final phi = m['phi_hari'];
    if (phi != null && phi is! int) {
      throw const FormatException('Field phi_hari tidak valid.');
    }
    if (m['terverifikasi'] is! bool) {
      throw const FormatException('Field terverifikasi tidak valid.');
    }
    return Medicine(
      id: _str(m, 'id_katalog'),
      activeIngredient: _str(m, 'bahan_aktif'),
      kind: MedicineKind.parse(m['jenis']),
      moaCode: _strOrNull(m, 'kode_moa'),
      moaName: _strOrNull(m, 'nama_moa'),
      note: _strOrNull(m, 'catatan'),
      preHarvestDays: phi as int?,
      preHarvestSource: _strOrNull(m, 'phi_sumber'),
      source: _str(m, 'sumber'),
      verified: m['terverifikasi'] as bool,
    );
  }

  final String id;
  final String activeIngredient;

  final MedicineKind kind;
  final String? moaCode;
  final String? moaName;
  final String? note;

  /// Masa tunggu panen; null berarti belum diketahui dan harus dicek pada label produk.
  final int? preHarvestDays;

  /// Asal angka masa tunggu panen (mis. label luar negeri). Selalu terisi bila [preHarvestDays] terisi.
  final String? preHarvestSource;
  final String source;
  final bool verified;
}

/// Jumlah stok yang sah: sama dengan `positiveDecimalSchema` backend (paling banyak 2 desimal).
final RegExp _quantityPattern = RegExp(r'^\d{1,10}(\.\d{1,2})?$');

/// Ubah ketikan pengguna (koma atau titik) menjadi jumlah baku, atau null bila tidak sah atau nol.
String? normalizeQuantity(String raw) {
  final value = raw.trim().replaceAll(',', '.');
  if (!_quantityPattern.hasMatch(value)) return null;
  if (double.parse(value) <= 0) return null;
  return value;
}

/// Satu baris bahan dari inventaris yang dipakai saat menerima rekomendasi.
class StockLineDraft {
  const StockLineDraft({
    required this.inventoryId,
    required this.amount,
    required this.unit,
  });

  final String inventoryId;

  /// Jumlah baku, mis. `10` atau `2.5` (lihat [normalizeQuantity]).
  final String amount;
  final String unit;

  Map<String, dynamic> toJson() => {
    'id_inventaris': inventoryId,
    'jumlah': amount,
    'satuan': unit,
  };
}

/// Bahan stok yang benar-benar terpotong untuk satu perawatan.
class MaterialUsed {
  const MaterialUsed({
    required this.inventoryId,
    required this.name,
    required this.amount,
    required this.unit,
  });

  factory MaterialUsed.fromJson(Object? json) {
    final m = _map(json, 'Bahan');
    return MaterialUsed(
      inventoryId: _str(m, 'id_inventaris'),
      name: _str(m, 'nama_barang'),
      amount: _str(m, 'jumlah'),
      unit: _str(m, 'satuan'),
    );
  }

  final String inventoryId;
  final String name;
  final String amount;
  final String unit;
}

class PestRecommendation {
  const PestRecommendation({
    required this.id,
    required this.tableId,
    required this.tableCode,
    required this.scanId,
    required this.pest,
    required this.severity,
    required this.status,
    required this.medicine,
    required this.ruleId,
    required this.reason,
    required this.rejectionReason,
    required this.rejectionNote,
    required this.appliedOn,
    required this.careNote,
    required this.createdAt,
    required this.decidedAt,
    required this.materials,
  });

  factory PestRecommendation.fromJson(Object? json) {
    final m = _map(json, 'Rekomendasi');
    final pest = PestKind.fromApiCode(_str(m, 'hama'));
    if (pest == null) throw FormatException('Hama tidak dikenal: ${m['hama']}');
    final severity = PestSeverity.values.where(
      (s) => s.apiCode == m['tingkat'],
    );
    if (severity.isEmpty) {
      throw FormatException('Tingkat tidak dikenal: ${m['tingkat']}');
    }
    final created = DateTime.tryParse(_str(m, 'tanggal_rekomendasi'));
    if (created == null) {
      throw const FormatException('Tanggal rekomendasi tidak valid.');
    }
    final decidedRaw = _strOrNull(m, 'tanggal_keputusan');
    final materials = m['bahan_terpakai'];
    if (materials is! List) {
      throw const FormatException('Field bahan_terpakai tidak valid.');
    }
    return PestRecommendation(
      id: _str(m, 'id_rekomendasi'),
      tableId: _str(m, 'id_meja'),
      tableCode: _str(m, 'kode_meja'),
      scanId: _strOrNull(m, 'id_hasil_deteksi'),
      pest: pest,
      severity: severity.first,
      status: RecommendationStatus.parse(m['status']),
      medicine: Medicine.fromJson(m['obat']),
      ruleId: _str(m, 'rule_id'),
      reason: _str(m, 'alasan'),
      rejectionReason: RejectReason.tryParse(m['alasan_penolakan']),
      rejectionNote: _strOrNull(m, 'catatan_penolakan'),
      appliedOn: _strOrNull(m, 'tanggal_aplikasi'),
      careNote: _strOrNull(m, 'catatan_perawatan'),
      createdAt: created,
      decidedAt: decidedRaw == null ? null : DateTime.tryParse(decidedRaw),
      materials: materials.map(MaterialUsed.fromJson).toList(growable: false),
    );
  }

  final String id;
  final String tableId;
  final String tableCode;
  final String? scanId;
  final PestKind pest;
  final PestSeverity severity;
  final RecommendationStatus status;
  final Medicine medicine;
  final String ruleId;

  /// Penjelasan "kenapa obat ini" dari mesin rotasi.
  final String reason;
  final RejectReason? rejectionReason;
  final String? rejectionNote;

  /// YYYY-MM-DD, terisi bila diterima.
  final String? appliedOn;
  final String? careNote;
  final DateTime createdAt;
  final DateTime? decidedAt;

  /// Stok yang terpotong saat diterima; kosong bila tanpa bahan atau belum diterima.
  final List<MaterialUsed> materials;
}

class RecommendationPage {
  const RecommendationPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  final List<PestRecommendation> items;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}
