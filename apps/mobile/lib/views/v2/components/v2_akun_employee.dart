/// Satu akun pegawai pada alur "03 Akun".
///
/// Bentuknya mengikuti frame FigCraft: nama, username, telepon, alamat, dan
/// status aktif. Selama backend akun v2 belum disambungkan, daftar contoh di
/// [designEmployees] dipakai supaya alur 3.5 sampai 3.17 bisa dicoba.
class V2Employee {
  const V2Employee({
    required this.id,
    required this.name,
    required this.username,
    this.phone = '',
    this.address = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String username;
  final String phone;
  final String address;
  final bool active;

  /// Dua huruf pertama nama untuk avatar (frame 3.1: "BS", 3.11: "SD").
  String get initials => v2InitialsOf(name);

  /// Baris kedua daftar: "Aktif, sari.dewi" / "Nonaktif, agus.s".
  String get statusLine => '${active ? 'Aktif' : 'Nonaktif'}, $username';

  /// Nama depan untuk judul/notifikasi (frame 3.15: "Nonaktifkan Sari?").
  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.first;
  }

  V2Employee copyWith({
    String? name,
    String? username,
    String? phone,
    String? address,
    bool? active,
  }) {
    return V2Employee(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      active: active ?? this.active,
    );
  }
}

/// Hasil halaman detail pegawai: menyimpan perubahan atau menonaktifkan.
sealed class V2EmployeeResult {
  const V2EmployeeResult(this.employee);

  final V2Employee employee;
}

/// Hasil halaman detail saat data pegawai berubah (frame 3.12 → 3.14).
class V2EmployeeSaved extends V2EmployeeResult {
  const V2EmployeeSaved(super.employee);
}

/// Hasil halaman detail saat pegawai dinonaktifkan (frame 3.15 → 3.16).
class V2EmployeeDeactivated extends V2EmployeeResult {
  const V2EmployeeDeactivated(super.employee);
}

/// Hasil halaman detail saat pegawai nonaktif diaktifkan kembali (D-36).
class V2EmployeeActivated extends V2EmployeeResult {
  const V2EmployeeActivated(super.employee);
}

/// Inisial dua kata pertama sebuah nama (dipakai kartu Profil dan avatar baris).
String v2InitialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

/// Daftar akun contoh dari frame `3.5 Akun pegawai`.
const List<V2Employee> designEmployees = <V2Employee>[
  V2Employee(
    id: 'sari',
    name: 'Sari Dewi',
    username: 'sari.dewi',
    phone: '0812 3456 7890',
    address: 'Jl. Melati 12, Malang',
  ),
  V2Employee(id: 'rina', name: 'Rina Putri', username: 'rina.putri'),
  V2Employee(id: 'dedi', name: 'Dedi Kurnia', username: 'dedi.k'),
  V2Employee(id: 'agus', name: 'Agus Salim', username: 'agus.s', active: false),
];
