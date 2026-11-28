part of 'pest_models.dart';

/// Hasil pencocokan bahan dengan daftar pestisida Indonesia. Daftar yang dipakai tidak memuat
/// satu pun entri selada, jadi tidak ada status "terdaftar untuk selada".
enum RegistrationStatus {
  otherCrop('tercatat_komoditas_lain'),
  notFound('tidak_ditemukan'),
  notPesticide('bukan_pestisida'),
  unchecked('belum_diperiksa');

  const RegistrationStatus(this.apiCode);

  final String apiCode;

  /// Nilai yang tidak dikenal atau kosong dianggap belum diperiksa.
  static RegistrationStatus parse(Object? value) {
    for (final s in RegistrationStatus.values) {
      if (s.apiCode == value) return s;
    }
    return RegistrationStatus.unchecked;
  }
}

/// Satu langkah rencana rotasi.
class RotationStep {
  const RotationStep({
    required this.order,
    required this.activeIngredient,
    required this.moaCode,
    required this.remaining,
  });

  factory RotationStep.fromJson(Object? json) {
    final m = _map(json, 'Langkah rotasi');
    final order = m['urutan'];
    final remaining = m['sisa_jatah'];
    if (order is! int || (remaining != null && remaining is! int)) {
      throw const FormatException('Langkah rotasi tidak valid.');
    }
    return RotationStep(
      order: order,
      activeIngredient: _str(m, 'bahan_aktif'),
      moaCode: _strOrNull(m, 'kode_moa'),
      remaining: remaining as int?,
    );
  }

  final int order;
  final String activeIngredient;
  final String? moaCode;

  /// Sisa semprot cara kerja ini dalam 30 hari; null berarti tidak dibatasi.
  final int? remaining;
}

/// Kombinasi cara kerja berbeda yang bisa dipakai bergantian. Langkah pertama
/// adalah saran yang sedang diterima atau ditolak.
class RotationPlan {
  const RotationPlan({required this.combinationCount, required this.steps});

  /// Null untuk saran lama yang dibuat sebelum rencana disimpan.
  static RotationPlan? tryFromJson(Object? json) {
    if (json == null) return null;
    final m = _map(json, 'Rencana rotasi');
    final count = m['jumlah_kombinasi'];
    final steps = m['langkah'];
    if (count is! int || steps is! List) {
      throw const FormatException('Rencana rotasi tidak valid.');
    }
    return RotationPlan(
      combinationCount: count,
      steps: steps.map(RotationStep.fromJson).toList(growable: false),
    );
  }

  final int combinationCount;
  final List<RotationStep> steps;
}
