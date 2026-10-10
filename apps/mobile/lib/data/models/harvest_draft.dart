import 'harvest_record.dart';

class HarvestDraftRow {
  const HarvestDraftRow({
    required this.transferId,
    required this.plantCount,
    required this.total,
    required this.reject,
  });
  final String transferId, total, reject;
  final int plantCount;
  Map<String, dynamic> toJson() => {
    'id_pemindahan': transferId,
    'jumlah_tanaman': plantCount,
    'berat_total': HarvestWeight.parse(total, ui: true).wire,
    'berat_reject': HarvestWeight.parse(reject, ui: true).wire,
  };
}

class HarvestDraft {
  const HarvestDraft({required this.date, required this.rows, this.note});
  final String date;
  final String? note;
  final List<HarvestDraftRow> rows;
  Map<String, dynamic> toJson() => {
    'tanggal_panen': date,
    'keterangan': normalizedHarvestNote(note),
    'details': rows.map((r) => r.toJson()).toList(),
  };
}

String? normalizedHarvestNote(String? note) =>
    note?.trim().isNotEmpty == true ? note!.trim() : null;

class HarvestCorrectionRow {
  const HarvestCorrectionRow({
    required this.detailId,
    required this.total,
    required this.reject,
  });
  final String detailId, total, reject;
  Map<String, dynamic> toJson() => {
    'id_detail_panen': detailId,
    'berat_total': HarvestWeight.parse(total, ui: true).wire,
    'berat_reject': HarvestWeight.parse(reject, ui: true).wire,
  };
}

class HarvestCorrection {
  const HarvestCorrection({
    required this.id,
    required this.expectedVersion,
    this.note,
    this.rows,
  });
  final String id, expectedVersion;
  final String? note;
  final List<HarvestCorrectionRow>? rows;
  Map<String, dynamic> toJson() => {
    'expected_version': expectedVersion,
    'keterangan': normalizedHarvestNote(note),
    if (rows != null) 'details': rows!.map((r) => r.toJson()).toList(),
  };
}
