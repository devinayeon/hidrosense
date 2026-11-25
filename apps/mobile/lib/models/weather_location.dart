/// Tingkat wilayah administratif; urutannya turun dari provinsi ke desa.
enum WeatherRegionLevel {
  province,
  regency,
  district,
  village;

  /// Nilai `level` pada API cuaca backend.
  String get apiName => name;

  WeatherRegionLevel? get next =>
      index + 1 < values.length ? values[index + 1] : null;

  String get label => switch (this) {
    province => 'provinsi',
    regency => 'kabupaten/kota',
    district => 'kecamatan',
    village => 'desa/kelurahan',
  };
}

/// Satu baris daftar wilayah. Hanya desa/kelurahan yang punya [adm4], yaitu
/// kode yang diminta API prakiraan BMKG.
class WeatherRegion {
  const WeatherRegion({required this.id, required this.name, this.adm4});

  final String id;
  final String name;
  final String? adm4;
}

/// Lokasi prakiraan cuaca BMKG: satu desa/kelurahan.
class WeatherLocation {
  const WeatherLocation({
    required this.adm4,
    required this.village,
    required this.district,
    required this.regency,
    this.province = '',
    this.approximate = false,
  });

  /// Kode wilayah Kemendagri tingkat IV, mis. `35.09.12.2002`.
  final String adm4;
  final String village;
  final String district;
  final String regency;
  final String province;

  /// Desa dipilih terdekat di kecamatan yang sama karena desa persis pengguna
  /// tidak dikenali.
  final bool approximate;

  static final RegExp adm4Pattern = RegExp(r'^\d{2}\.\d{2}\.\d{2}\.\d{4}$');

  /// Lokasi mitra HidroSense (Desa Sabrang, Ambulu, Jember), dipakai sampai
  /// pengguna memilih lokasi lain. Kodenya bisa diganti saat build lewat
  /// `--dart-define=BMKG_ADM4=...`.
  static const WeatherLocation partner = WeatherLocation(
    adm4: String.fromEnvironment('BMKG_ADM4', defaultValue: '35.09.12.2002'),
    village: 'Sabrang',
    district: 'Ambulu',
    regency: 'Kabupaten Jember',
    province: 'Jawa Timur',
  );

  /// Label pendek untuk judul halaman: "Sabrang, Ambulu".
  String get shortLabel => '$village, $district';

  /// Label lengkap: "Sabrang, Ambulu, Kabupaten Jember".
  String get label => '$village, $district, $regency';

  Map<String, dynamic> toJson() => {
    'adm4': adm4,
    'village': village,
    'district': district,
    'regency': regency,
    'province': province,
    'approximate': approximate,
  };

  /// `null` kalau isinya rusak atau kodenya bukan adm4; pemanggil memakai
  /// lokasi bawaan.
  static WeatherLocation? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final adm4 = json['adm4'];
    final village = json['village'];
    final district = json['district'];
    final regency = json['regency'];
    if (adm4 is! String ||
        !adm4Pattern.hasMatch(adm4) ||
        village is! String ||
        district is! String ||
        regency is! String) {
      return null;
    }
    final province = json['province'];
    return WeatherLocation(
      adm4: adm4,
      village: village,
      district: district,
      regency: regency,
      province: province is String ? province : '',
      approximate: json['approximate'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WeatherLocation &&
      other.adm4 == adm4 &&
      other.village == village &&
      other.district == district &&
      other.regency == regency;

  @override
  int get hashCode => Object.hash(adm4, village, district, regency);
}
