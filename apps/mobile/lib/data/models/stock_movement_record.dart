class StockDetailLine {
  const StockDetailLine({
    required this.idDetail,
    required this.inventoryId,
    required this.amount,
    required this.unit,
  });

  final String idDetail;
  final String inventoryId;
  final String amount;
  final String unit;

  factory StockDetailLine.fromJson(Map<String, dynamic> json) {
    if (json['id_detail_stok'] is! String ||
        json['id_inventaris'] is! String ||
        json['jumlah'] is! String ||
        json['satuan'] is! String) {
      throw const FormatException('Line detail stok tidak valid.');
    }
    return StockDetailLine(
      idDetail: json['id_detail_stok'] as String,
      inventoryId: json['id_inventaris'] as String,
      amount: json['jumlah'] as String,
      unit: json['satuan'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_detail_stok': idDetail,
    'id_inventaris': inventoryId,
    'jumlah': amount,
    'satuan': unit,
  };
}

class StockMovementRecord {
  const StockMovementRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.direction,
    this.note,
    this.reversalOf,
    required this.details,
  });

  final String id;
  final String userId;
  final DateTime date;
  final String direction; // 'masuk' | 'keluar'
  final String? note;
  final String? reversalOf;
  final List<StockDetailLine> details;

  factory StockMovementRecord.fromJson(Map<String, dynamic> json) {
    if (json['id_stok'] is! String ||
        json['id_user'] is! String ||
        json['tanggal_stok'] is! String ||
        (json['jenis_stok'] != 'masuk' && json['jenis_stok'] != 'keluar') ||
        json['details'] is! List) {
      throw const FormatException('Data mutasi stok tidak valid.');
    }

    final rawDetails = json['details'] as List;
    return StockMovementRecord(
      id: json['id_stok'] as String,
      userId: json['id_user'] as String,
      date: DateTime.parse(json['tanggal_stok'] as String),
      direction: json['jenis_stok'] as String,
      note: json['keterangan'] as String?,
      reversalOf: json['reversal_of'] as String?,
      details: rawDetails
          .map((d) => StockDetailLine.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}
