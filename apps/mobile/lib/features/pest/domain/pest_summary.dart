import 'yolo_decoder.dart';

/// Kode hama di aplikasi. Model YOLOv11n terbaru mendeteksi dua kelas target (`modelClasses`:
/// `0 = whitefly`, `1 = aphids`), sementara nilai `thrips` tetap dipertahankan pada enum agar
/// riwayat pindaian dan rekomendasi lama dari API backend tetap terbaca tanpa galat.
///
/// Ambang tingkat serangan diambil dari kuantil jumlah hama per foto positif pada data latih
/// (`ml/reports/dataset_provenance.json`): sedang mulai P75, berat mulai P90. Pengguna tetap
/// dapat mengubah tingkat serangan sebelum menyimpan.
enum PestKind {
  thrips('thrips', 'Thrips', sedangMin: 3, beratMin: 8),
  whitefly('whitefly', 'Kutu kebul', sedangMin: 2, beratMin: 5),
  aphids('aphids', 'Kutu daun', sedangMin: 2, beratMin: 3);

  const PestKind(
    this.apiCode,
    this.label, {
    required this.sedangMin,
    required this.beratMin,
  });

  /// Urutan kelas keluaran model TFLite (`ml/artifacts/labels.txt`).
  static const List<PestKind> modelClasses = [
    PestKind.whitefly,
    PestKind.aphids,
  ];

  /// Kode yang dipakai API backend.
  final String apiCode;
  final String label;

  /// Jumlah per foto mulai tingkat sedang (P75 data latih).
  final int sedangMin;

  /// Jumlah per foto mulai tingkat berat (P90 data latih).
  final int beratMin;

  static PestKind fromClassId(int id) {
    if (id < 0 || id >= modelClasses.length) {
      throw RangeError('Kelas hama tidak dikenal pada model 2 kelas: $id');
    }
    return modelClasses[id];
  }

  static PestKind? fromApiCode(String code) {
    for (final kind in PestKind.values) {
      if (kind.apiCode == code) return kind;
    }
    return null;
  }
}

/// Tingkat serangan pada satu foto. Nilainya sama dengan enum `tingkat` di backend.
enum PestSeverity {
  ringan('ringan', 'Ringan'),
  sedang('sedang', 'Sedang'),
  berat('berat', 'Berat');

  const PestSeverity(this.apiCode, this.label);

  final String apiCode;
  final String label;
}

PestSeverity suggestSeverity(PestKind kind, int count) {
  if (count >= kind.beratMin) return PestSeverity.berat;
  if (count >= kind.sedangMin) return PestSeverity.sedang;
  return PestSeverity.ringan;
}

/// Hitungan satu hama pada satu foto.
class PestFinding {
  const PestFinding({
    required this.kind,
    required this.count,
    required this.maxConfidence,
  });

  final PestKind kind;
  final int count;
  final double maxConfidence;

  PestSeverity get suggestedSeverity => suggestSeverity(kind, count);
}

/// Ringkas deteksi menjadi hitungan per hama, urut menurut indeks model.
List<PestFinding> summarizeDetections(Iterable<YoloDetection> detections) {
  final counts = <int, int>{};
  final best = <int, double>{};
  for (final d in detections) {
    counts[d.classId] = (counts[d.classId] ?? 0) + 1;
    final current = best[d.classId] ?? 0;
    if (d.confidence > current) best[d.classId] = d.confidence;
  }
  final ids = counts.keys.toList()..sort();
  return [
    for (final id in ids)
      PestFinding(
        kind: PestKind.fromClassId(id),
        count: counts[id]!,
        maxConfidence: best[id]!,
      ),
  ];
}
