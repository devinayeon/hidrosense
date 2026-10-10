import '../../core/business_date.dart';

String harvestId(Object? value) {
  if (value is! String ||
      !RegExp(r'^[1-9][0-9]*$').hasMatch(value) ||
      value.contains('\n') ||
      value.length > 19 ||
      BigInt.parse(value) > BigInt.parse('9223372036854775807')) {
    throw const FormatException('Identitas panen tidak valid.');
  }
  return value;
}

String harvestDate(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null || apiDate(parsed) != value) {
    throw const FormatException('Tanggal panen tidak valid.');
  }
  return value as String;
}

class HarvestWeight {
  HarvestWeight._(this.minor);
  final BigInt minor;
  static final maximum = BigInt.from(9999999999);
  factory HarvestWeight.parse(
    String text, {
    bool ui = false,
    bool aggregate = false,
  }) {
    if (text.contains('\n') || text.contains('\r')) {
      throw const FormatException('Berat panen tidak valid.');
    }
    final normalized = ui ? text.trim().replaceAll(',', '.') : text;
    if (!RegExp(r'^[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(normalized) ||
        normalized.contains('\n')) {
      throw const FormatException(
        'Gunakan kilogram dengan maksimal dua desimal.',
      );
    }
    final parts = normalized.split('.');
    final minor =
        BigInt.parse(parts[0]) * BigInt.from(100) +
        BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    if (minor > maximum * BigInt.from(aggregate ? 100 : 1)) {
      throw const FormatException('Berat melebihi batas layanan.');
    }
    return HarvestWeight._(minor);
  }
  factory HarvestWeight.sum(Iterable<HarvestWeight> weights) =>
      HarvestWeight._(weights.fold(BigInt.zero, (a, b) => a + b.minor));
  String get wire =>
      '${minor ~/ BigInt.from(100)}.${(minor % BigInt.from(100)).toString().padLeft(2, '0')}';
  HarvestWeight subtract(HarvestWeight other) =>
      HarvestWeight._(minor - other.minor);
}

class HarvestDetail {
  const HarvestDetail({
    required this.id,
    required this.transferId,
    required this.tableId,
    required this.tableCode,
    required this.sowingDate,
    required this.transferDate,
    required this.plantCount,
    required this.saleable,
    this.total,
    this.reject,
  });
  final String id, transferId, tableId, tableCode, sowingDate, transferDate;
  final int plantCount;
  final HarvestWeight saleable;
  final HarvestWeight? total, reject;
  factory HarvestDetail.fromJson(Map<String, dynamic> json) {
    final count = json['jumlah_tanaman'];
    if (count is! int ||
        count < 1 ||
        count > 1000000 ||
        json['kode_meja'] is! String) {
      throw const FormatException('Rincian panen tidak valid.');
    }
    final total = _weight(json['berat_total']);
    final reject = _weight(json['berat_reject']);
    final saleable = _weight(json['berat_layak']);
    if (saleable == null ||
        (total == null) != (reject == null) ||
        (total != null &&
            (total.minor <= BigInt.zero ||
                total.minor != reject!.minor + saleable.minor))) {
      throw const FormatException('Sortasi panen tidak valid.');
    }
    return HarvestDetail(
      id: harvestId(json['id_detail_panen']),
      transferId: harvestId(json['id_pemindahan']),
      tableId: harvestId(json['id_meja']),
      tableCode: json['kode_meja'],
      sowingDate: harvestDate(json['tanggal_semai']),
      transferDate: harvestDate(json['tanggal_pemindahan']),
      plantCount: count,
      total: total,
      reject: reject,
      saleable: saleable,
    );
  }
}

HarvestWeight? _weight(Object? value, {bool aggregate = false}) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Berat panen tidak valid.');
  return HarvestWeight.parse(value, aggregate: aggregate);
}

class HarvestRecord {
  const HarvestRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.details,
    required this.saleable,
    this.total,
    this.reject,
    this.version,
    this.publicId,
    this.note,
  });
  final String id, userId, date;
  final String? version, publicId, note;
  final List<HarvestDetail> details;
  final HarvestWeight saleable;
  final HarvestWeight? total, reject;
  int get plantCount => details.fold(0, (a, b) => a + b.plantCount);
  factory HarvestRecord.fromJson(Map<String, dynamic> json) {
    final raw = json['details'];
    if (raw is! List ||
        raw.isEmpty ||
        raw.length > 100 ||
        (json['keterangan'] != null && json['keterangan'] is! String) ||
        (json['public_id'] != null && json['public_id'] is! String)) {
      throw const FormatException('Data panen tidak valid.');
    }
    final details = raw.map((r) {
      if (r is! Map<String, dynamic>) {
        throw const FormatException('Rincian panen tidak valid.');
      }
      return HarvestDetail.fromJson(r);
    }).toList();
    if (details.map((d) => d.id).toSet().length != details.length) {
      throw const FormatException('Rincian panen berulang.');
    }
    final total = _weight(json['berat_total'], aggregate: true);
    final reject = _weight(json['berat_reject'], aggregate: true);
    final saleable = _weight(json['berat_layak'], aggregate: true);
    final known = details.every((d) => d.total != null);
    if (saleable == null ||
        saleable.minor !=
            HarvestWeight.sum(details.map((d) => d.saleable)).minor ||
        known != (total != null && reject != null) ||
        (!known && (total != null || reject != null)) ||
        (known &&
            (total!.minor !=
                    HarvestWeight.sum(details.map((d) => d.total!)).minor ||
                reject!.minor !=
                    HarvestWeight.sum(details.map((d) => d.reject!)).minor))) {
      throw const FormatException('Total panen tidak sesuai rincian.');
    }
    return HarvestRecord(
      id: harvestId(json['id_panen']),
      userId: harvestId(json['id_user']),
      date: harvestDate(json['tanggal_panen']),
      version: json['version'] == null ? null : harvestId(json['version']),
      publicId: json['public_id'],
      note: json['keterangan'],
      details: List.unmodifiable(details),
      total: total,
      reject: reject,
      saleable: saleable,
    );
  }
}
