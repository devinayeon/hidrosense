import 'v2_akun_employee.dart';

/// Isian form akun pegawai sebelum dikirim ke backend.
class V2EmployeeDraft {
  const V2EmployeeDraft({
    required this.name,
    required this.username,
    this.password,
    this.phone = '',
    this.address = '',
  });

  final String name;
  final String username;

  /// Wajib saat menambah; kosong saat ubah berarti password tidak diganti.
  final String? password;
  final String phone;
  final String address;
}

/// Jembatan alur "03 Akun" ke backend pegawai.
///
/// Kalau store tidak diberikan (galeri/pratinjau), halaman memakai daftar
/// contoh [designEmployees] dan mengubahnya di memori saja.
abstract interface class V2EmployeeStore {
  Future<List<V2Employee>> list();

  Future<V2Employee> create(V2EmployeeDraft draft);

  Future<V2Employee> update(String id, V2EmployeeDraft draft);

  Future<V2Employee> deactivate(String id);

  /// Mengaktifkan kembali pegawai nonaktif (D-36). Server sudah menyediakan
  /// `POST /employees/:id/activate`; aksi ini hanya membuka jalannya di UI.
  Future<V2Employee> activate(String id);
}

/// Galat store yang pesannya sudah siap ditampilkan ke pengguna.
class V2EmployeeStoreException implements Exception {
  const V2EmployeeStoreException(this.message, {this.code});

  final String message;

  /// Kode galat server bila ada, mis. `PASSWORD_UNCHANGED`, supaya form bisa
  /// menaruh pesannya di isian yang tepat, bukan hanya snackbar.
  final String? code;

  @override
  String toString() => message;
}
