import '../../core/business_date.dart';
import 'harvest_record.dart';

String saleId(Object? value) {
  if (value is! String ||
      !RegExp(r'^[1-9][0-9]*$').hasMatch(value) ||
      value.contains('\n') ||
      value.length > 19 ||
      BigInt.parse(value) > BigInt.parse('9223372036854775807')) {
    throw const FormatException('Identitas penjualan tidak valid.');
  }
  return value;
}

String saleDate(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null || apiDate(parsed) != value) {
    throw const FormatException('Tanggal penjualan tidak valid.');
  }
  return value as String;
}

HarvestWeight _weight(Object? value, {bool aggregate = false}) {
  if (value is! String) {
    throw const FormatException('Berat penjualan tidak valid.');
  }
  return HarvestWeight.parse(value, aggregate: aggregate);
}

double _amount(Object? value, {bool positive = true}) {
  if (value is! String || !RegExp(r'^[0-9]{1,20}\.[0-9]{2}$').hasMatch(value)) {
    throw const FormatException('Nilai rupiah penjualan tidak valid.');
  }
  final parsed = double.tryParse(value);
  if (parsed == null || !parsed.isFinite || (positive && parsed <= 0)) {
    throw const FormatException('Nilai rupiah penjualan tidak valid.');
  }
  return parsed;
}

String _moneyWire(Object? value) {
  if (value is! String || !RegExp(r'^[0-9]{1,20}\.[0-9]{2}$').hasMatch(value)) {
    throw const FormatException('Nilai rupiah penjualan tidak valid.');
  }
  if (value == '0.00') {
    throw const FormatException('Nilai rupiah penjualan tidak valid.');
  }
  return value;
}

String _normalizePriceWire(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  final match = RegExp(
    r'^([0-9]{1,10})(?:\.([0-9]{1,2}))?$',
  ).firstMatch(normalized);
  if (match == null) {
    throw const FormatException(
      'Harga per Kg harus lebih dari 0 dengan maksimal dua desimal.',
    );
  }
  final whole = BigInt.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final minor = whole * BigInt.from(100) + BigInt.parse(fraction);
  if (minor <= BigInt.zero || minor > BigInt.parse('999999999999')) {
    throw const FormatException(
      'Harga per Kg harus lebih dari 0 dengan maksimal dua desimal.',
    );
  }
  return '${whole == BigInt.zero ? '0' : whole.toString()}.$fraction';
}

class SaleDetail {
  const SaleDetail({
    required this.id,
    required this.harvestId,
    required this.harvestDate,
    required this.quantity,
    required this.price,
    required this.priceWire,
    required this.total,
    this.saleable,
  });

  final String id;
  final String harvestId;
  final String harvestDate;
  final HarvestWeight quantity;
  final double price;
  final String priceWire;
  final double total;
  final HarvestWeight? saleable;

  factory SaleDetail.fromJson(Map<String, dynamic> json) {
    final quantity = _weight(json['jumlah_kg']);
    if (quantity.minor <= BigInt.zero) {
      throw const FormatException('Berat penjualan tidak valid.');
    }
    final priceWire = _moneyWire(json['harga_per_kg']);
    return SaleDetail(
      id: saleId(json['id_detail_penjualan']),
      harvestId: saleId(json['id_panen']),
      harvestDate: saleDate(json['tanggal_panen']),
      quantity: quantity,
      price: double.parse(priceWire),
      priceWire: priceWire,
      total: _amount(json['total_harga'], positive: false),
      saleable: json['berat_layak'] == null
          ? null
          : _weight(json['berat_layak']),
    );
  }
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.buyer,
    required this.status,
    required this.details,
    this.note,
    this.version,
    this.publicId,
  });

  final String id, userId, date, buyer, status;
  final String? note, version, publicId;
  final List<SaleDetail> details;

  HarvestWeight get quantity =>
      HarvestWeight.sum(details.map((detail) => detail.quantity));
  double get total => details.fold(0.0, (sum, detail) => sum + detail.total);

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    final raw = json['details'];
    final version = json['version'];
    if (raw is! List ||
        raw.isEmpty ||
        raw.length > 100 ||
        json['pembeli'] is! String ||
        (json['pembeli'] as String).length > 100 ||
        !['lunas', 'belum_lunas'].contains(json['status_pembayaran']) ||
        (json['keterangan'] != null &&
            (json['keterangan'] is! String ||
                (json['keterangan'] as String).length > 1000)) ||
        (json['public_id'] != null && json['public_id'] is! String) ||
        (version != null && (version is! String || version.isEmpty))) {
      throw const FormatException('Data penjualan tidak valid.');
    }
    final details = raw.map((row) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Rincian penjualan tidak valid.');
      }
      return SaleDetail.fromJson(row);
    }).toList();
    if (details.map((detail) => detail.id).toSet().length != details.length) {
      throw const FormatException('Rincian penjualan berulang.');
    }
    return SaleRecord(
      id: saleId(json['id_penjualan']),
      userId: saleId(json['id_user']),
      date: saleDate(json['tanggal_penjualan']),
      buyer: json['pembeli'] as String,
      status: json['status_pembayaran'] as String,
      note: json['keterangan'] as String?,
      version: version == null ? null : saleId(version),
      publicId: json['public_id'] as String?,
      details: List.unmodifiable(details),
    );
  }
}

/// Payload yang dikirim aplikasi: satu transaksi = satu batch panen.
class SalesDraft {
  const SalesDraft({
    required this.date,
    required this.buyer,
    required this.status,
    required this.harvestId,
    required this.quantity,
    required this.price,
    this.note,
    this.priceWireInput,
  });

  final String date, buyer, status, harvestId;
  final double quantity, price;
  final String? note;
  final String? priceWireInput;

  String get quantityWire {
    final scaled = quantity * 100;
    if (!quantity.isFinite ||
        quantity <= 0 ||
        (scaled - scaled.round()).abs() > 1e-6) {
      throw const FormatException(
        'Berat jual harus lebih dari 0 dengan maksimal dua desimal.',
      );
    }
    return quantity.toStringAsFixed(2);
  }

  String get priceWire {
    final exact = priceWireInput;
    if (exact != null) return _normalizePriceWire(exact);
    final scaled = price * 100;
    if (!price.isFinite ||
        price <= 0 ||
        (scaled - scaled.round()).abs() > 1e-6) {
      throw const FormatException(
        'Harga per Kg harus lebih dari 0 dengan maksimal dua desimal.',
      );
    }
    return price.toStringAsFixed(2);
  }

  Map<String, dynamic> toJson() => {
    'tanggal_penjualan': date,
    'pembeli': buyer,
    'status_pembayaran': status,
    'keterangan': note,
    'id_panen': harvestId,
    'jumlah_kg': quantityWire,
    'harga_per_kg': priceWire,
  };
}

/// Perubahan header saja, dipakai untuk transaksi multi-batch.
class SalesHeaderDraft {
  const SalesHeaderDraft({
    required this.date,
    required this.buyer,
    required this.status,
    this.note,
  });

  final String date, buyer, status;
  final String? note;

  Map<String, dynamic> toJson(String expectedVersion) => {
    'tanggal_penjualan': date,
    'pembeli': buyer,
    'status_pembayaran': status,
    'keterangan': note,
    'expected_version': expectedVersion,
  };
}
