// lib/models/baris_tanam_model.dart

enum BarisConditionStatus { perfect, warning }

class BarisTanam {
  final String id;
  final String name; // Contoh: "Baris A"
  final String holesRange; // Contoh: "Lubang 1-50"
  final int totalBibit;
  final int healthyCount;
  final int failedCount;
  final int hss;

  const BarisTanam({
    required this.id,
    required this.name,
    required this.holesRange,
    required this.totalBibit,
    required this.healthyCount,
    required this.failedCount,
    required this.hss,
  });

  bool get isPerfect => failedCount == 0;

  BarisConditionStatus get status =>
      isPerfect ? BarisConditionStatus.perfect : BarisConditionStatus.warning;

  BarisTanam copyWith({
    String? id,
    String? name,
    String? holesRange,
    int? totalBibit,
    int? healthyCount,
    int? failedCount,
    int? hss,
  }) {
    return BarisTanam(
      id: id ?? this.id,
      name: name ?? this.name,
      holesRange: holesRange ?? this.holesRange,
      totalBibit: totalBibit ?? this.totalBibit,
      healthyCount: healthyCount ?? this.healthyCount,
      failedCount: failedCount ?? this.failedCount,
      hss: hss ?? this.hss,
    );
  }
}
