class SeedingBatch {
  final String id;
  final String batchName;
  final String variety;
  final String dateText;
  final int seedCount;
  final int hss;
  final int totalHss;
  final int healthyCount;
  final String healthyPhase;
  final int damagedCount;
  final String damagedNote;
  final List<String> materials;
  final String statusLabel;
  final String? note;

  SeedingBatch({
    required this.id,
    required this.batchName,
    required this.variety,
    required this.dateText,
    required this.seedCount,
    required this.hss,
    this.totalHss = 15,
    this.healthyCount = 0,
    this.healthyPhase = '',
    this.damagedCount = 0,
    this.damagedNote = '',
    this.materials = const [],
    required this.statusLabel,
    this.note,
  });

  String get seedCountText => '$seedCount Bibit';
  String get hssText => '$hss HSS';

  // Helper getters untuk kalkulasi UI
  double get progressRatio =>
      (totalHss > 0) ? (hss / totalHss).clamp(0.0, 1.0) : 0.0;
  String get batchNumber => batchName.replaceAll(RegExp(r'[^0-9]'), '');

  factory SeedingBatch.fromJson(Map<String, dynamic> json) {
    return SeedingBatch(
      id: json['id'] ?? '',
      batchName: json['batchName'] ?? '',
      variety: json['variety'] ?? '',
      dateText: json['dateText'] ?? '',
      seedCount: json['seedCount'] ?? 0,
      hss: json['hss'] ?? 0,
      totalHss: json['totalHss'] ?? 15,
      healthyCount: json['healthyCount'] ?? 0,
      healthyPhase: json['healthyPhase'] ?? '',
      damagedCount: json['damagedCount'] ?? 0,
      damagedNote: json['damagedNote'] ?? '',
      materials: List<String>.from(json['materials'] ?? []),
      statusLabel: json['statusLabel'] ?? '',
      note: json['note'],
    );
  }
}
