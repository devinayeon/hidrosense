enum PanenStatus { estimasi, selesai }

class PanenItem {
  final String id;
  final String title;
  final String batchName;
  final String mejaInfo;
  final String? targetHss;
  final String dateText;
  final String processedDate;
  final String resultText;
  final PanenStatus status;

  final String totalWeight;
  final String targetWeight;
  final String layakPercent;
  final String rejectPercent;
  final String rejectWeight;
  final String asalMejaTanam;
  final String varietas;
  final String lamaBudidaya;
  final String gradeKualitas;

  // Field Tambahan Sesuai Design Form Input Panen
  final String? hargaEstimasi;
  final String? jumlahLayak;
  final String? jumlahReject;
  final String? catatanPanen;

  const PanenItem({
    required this.id,
    required this.title,
    required this.batchName,
    required this.mejaInfo,
    this.targetHss,
    required this.dateText,
    required this.processedDate,
    required this.resultText,
    required this.status,
    required this.totalWeight,
    required this.targetWeight,
    required this.layakPercent,
    required this.rejectPercent,
    required this.rejectWeight,
    required this.asalMejaTanam,
    required this.varietas,
    required this.lamaBudidaya,
    required this.gradeKualitas,
    this.hargaEstimasi,
    this.jumlahLayak,
    this.jumlahReject,
    this.catatanPanen,
  });

  bool get isEstimasi => status == PanenStatus.estimasi;

  PanenItem copyWith({
    String? id,
    String? title,
    String? batchName,
    String? mejaInfo,
    String? targetHss,
    String? dateText,
    String? processedDate,
    String? resultText,
    PanenStatus? status,
    String? totalWeight,
    String? targetWeight,
    String? layakPercent,
    String? rejectPercent,
    String? rejectWeight,
    String? asalMejaTanam,
    String? varietas,
    String? lamaBudidaya,
    String? gradeKualitas,
    String? hargaEstimasi,
    String? jumlahLayak,
    String? jumlahReject,
    String? catatanPanen,
  }) {
    return PanenItem(
      id: id ?? this.id,
      title: title ?? this.title,
      batchName: batchName ?? this.batchName,
      mejaInfo: mejaInfo ?? this.mejaInfo,
      targetHss: targetHss ?? this.targetHss,
      dateText: dateText ?? this.dateText,
      processedDate: processedDate ?? this.processedDate,
      resultText: resultText ?? this.resultText,
      status: status ?? this.status,
      totalWeight: totalWeight ?? this.totalWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      layakPercent: layakPercent ?? this.layakPercent,
      rejectPercent: rejectPercent ?? this.rejectPercent,
      rejectWeight: rejectWeight ?? this.rejectWeight,
      asalMejaTanam: asalMejaTanam ?? this.asalMejaTanam,
      varietas: varietas ?? this.varietas,
      lamaBudidaya: lamaBudidaya ?? this.lamaBudidaya,
      gradeKualitas: gradeKualitas ?? this.gradeKualitas,
      hargaEstimasi: hargaEstimasi ?? this.hargaEstimasi,
      jumlahLayak: jumlahLayak ?? this.jumlahLayak,
      jumlahReject: jumlahReject ?? this.jumlahReject,
      catatanPanen: catatanPanen ?? this.catatanPanen,
    );
  }
}
