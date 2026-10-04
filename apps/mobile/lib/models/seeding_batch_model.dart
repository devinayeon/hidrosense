class SeedingBatch {
  final String id;
  final String batchName;
  final String variety;
  final String dateText;
  final int seedCount;
  final int hss;
  final String statusLabel;
  final String? note;

  SeedingBatch({
    required this.id,
    required this.batchName,
    required this.variety,
    required this.dateText,
    required this.seedCount,
    required this.hss,
    required this.statusLabel,
    this.note,
  });

  String get seedCountText => '$seedCount Bibit';
  String get hssText => '$hss HSS';

  factory SeedingBatch.fromJson(Map<String, dynamic> json) {
    return SeedingBatch(
      id: json['id'] ?? '',
      batchName: json['batchName'] ?? '',
      variety: json['variety'] ?? '',
      dateText: json['dateText'] ?? '',
      seedCount: json['seedCount'] ?? 0,
      hss: json['hss'] ?? 0,
      statusLabel: json['statusLabel'] ?? '',
      note: json['note'],
    );
  }
}
