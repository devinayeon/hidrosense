/// Persisted API data. IDs and quantities never pass through floating point.
final class InventoryRecord {
  const InventoryRecord._({
    required this.id,
    required this.publicId,
    required this.version,
    required this.categoryId,
    required this.medicineId,
    required this.name,
    required this.unit,
    required this.minimum,
    required this.active,
    required this.category,
    required this.medicineName,
    required this.balance,
  });

  final String id;
  final String? publicId;
  final String? version;
  final String categoryId;
  final String? medicineId;
  final String name;
  final String unit;
  final String? minimum;
  final bool active;
  final String category;
  final String? medicineName;
  final String balance;

  BigInt get balanceMinor => _minor(balance);
  BigInt? get minimumMinor => minimum == null ? null : _minor(minimum!);
  bool get isLow => minimumMinor != null && balanceMinor < minimumMinor!;
  bool get isOutOfStock => RegExp(r'^0(?:\.0+)?$').hasMatch(balance);
  String get formattedStock => '$balance $unit';

  factory InventoryRecord.fromApi(
    Map<String, dynamic> master,
    Map<String, dynamic> balance,
  ) {
    if (![
      'id_inventaris',
      'satuan',
      'stok_minimum',
      'saldo',
      'di_bawah_minimum',
    ].every(balance.containsKey)) {
      throw const FormatException('Field saldo inventaris tidak lengkap.');
    }
    final record = InventoryRecord.fromJson({
      ...master,
      'saldo': balance['saldo'],
    });
    final balanceMinimum = balance['stok_minimum'] == null
        ? null
        : _decimal(balance['stok_minimum'], positive: true);
    if (balance['id_inventaris'] != record.id ||
        balance['satuan'] != record.unit ||
        balanceMinimum != record.minimum ||
        balance['di_bawah_minimum'] != record.isLow) {
      throw const FormatException(
        'Master dan saldo inventaris tidak konsisten.',
      );
    }
    return record;
  }

  factory InventoryRecord.fromJson(Map<String, dynamic> json) {
    const requiredFields = [
      'id_inventaris',
      'public_id',
      'version',
      'id_jenis_inventaris',
      'id_obat',
      'nama_barang',
      'satuan',
      'stok_minimum',
      'status_aktif',
      'nama_jenis',
      'nama_obat',
      'saldo',
    ];
    if (!requiredFields.every(json.containsKey)) {
      throw const FormatException('Field inventaris tidak lengkap.');
    }
    final publicId = json['public_id'];
    final version = json['version'];
    if ((publicId == null) != (version == null) ||
        (publicId != null &&
            (publicId is! String ||
                !RegExp(
                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                ).hasMatch(publicId)))) {
      throw const FormatException('Identitas sinkronisasi tidak valid.');
    }
    final status = json['status_aktif'];
    if (status is! int || (status != 0 && status != 1)) {
      throw const FormatException('Status inventaris tidak valid.');
    }
    return InventoryRecord._(
      id: _id(json['id_inventaris']),
      publicId: publicId as String?,
      version: version == null ? null : _id(version),
      categoryId: _id(json['id_jenis_inventaris']),
      medicineId: json['id_obat'] == null ? null : _id(json['id_obat']),
      name: _text(json['nama_barang'], 100),
      unit: _text(json['satuan'], 30),
      minimum: json['stok_minimum'] == null
          ? null
          : _decimal(json['stok_minimum'], positive: true),
      active: status == 1,
      category: _text(json['nama_jenis'], 50),
      medicineName: json['nama_obat'] == null
          ? null
          : _text(json['nama_obat'], 100),
      balance: _decimal(json['saldo']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id_inventaris': id,
    'public_id': publicId,
    'version': version,
    'id_jenis_inventaris': categoryId,
    'id_obat': medicineId,
    'nama_barang': name,
    'satuan': unit,
    'stok_minimum': minimum,
    'status_aktif': active ? 1 : 0,
    'nama_jenis': category,
    'nama_obat': medicineName,
    'saldo': balance,
  };

  static String _id(dynamic value) {
    if (value is! String ||
        !RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(value) ||
        BigInt.parse(value) > BigInt.parse('9223372036854775807')) {
      throw const FormatException('ID harus string integer positif signed64.');
    }
    return value;
  }

  static String _text(dynamic value, int max) {
    if (value is! String || value.trim().isEmpty || value.length > max) {
      throw const FormatException('Teks inventaris tidak valid.');
    }
    return value;
  }

  static BigInt _minor(String value) {
    final parts = value.split('.');
    return BigInt.parse(parts[0]) * BigInt.from(100) +
        BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  }

  static String _decimal(dynamic value, {bool positive = false}) {
    if (value is! String ||
        !RegExp(r'^[0-9]{1,10}(\.[0-9]{1,2})?$').hasMatch(value)) {
      throw const FormatException(
        'Jumlah harus string desimal maksimal dua pecahan.',
      );
    }
    final minor = _minor(value);
    if (positive && minor == BigInt.zero) {
      throw const FormatException('Stok minimum harus positif.');
    }
    final whole = minor ~/ BigInt.from(100);
    final fraction = (minor % BigInt.from(100))
        .toString()
        .padLeft(2, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole.$fraction';
  }
}
