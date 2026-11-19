import '../../../data/services/api_client.dart';

/// Pesan galat akun pegawai dalam bahasa manusia.
///
/// Dipakai bersama oleh `EmployeeViewModel` (v1) dan store v2 supaya kode galat
/// dari server diterjemahkan dengan kalimat yang sama.
String employeeErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.code == 'USERNAME_TAKEN') {
      return 'Username sudah digunakan oleh akun lain.';
    }
    if (error.code == 'ACCOUNT_DEACTIVATED') {
      return 'Akun sedang dinonaktifkan. Aktifkan kembali akun terlebih dahulu.';
    }
    if (error.code == 'VALIDATION_ERROR') {
      return 'Input data tidak valid. Periksa kembali form.';
    }
    return error.message;
  }
  if (error is FormatException) {
    return 'Format data tidak sesuai. Silakan muat ulang.';
  }
  return 'Terjadi kendala jaringan. Periksa koneksi Anda.';
}
