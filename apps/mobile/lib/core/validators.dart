/// Aturan isian bersama untuk form v2.
///
/// Semua fungsi mengembalikan pesan galat yang spesifik (bukan "tidak valid"),
/// atau `null` bila isian sah. Dipakai oleh form akun, semaian, dan meja supaya
/// pesannya konsisten dan bisa diuji terpisah.
library;

/// Pola huruf/angka dipakai aturan kompleksitas password.
final RegExp _huruf = RegExp(r'[A-Za-z]');
final RegExp _angka = RegExp(r'[0-9]');

/// Password: 6–8 karakter dan harus memuat huruf **dan** angka (keputusan SA).
///
/// Saat mengubah akun, password boleh dikosongkan (berarti tidak diganti) bila
/// [opsional] benar.
String? passwordProblem(String password, {bool optional = false}) {
  if (password.isEmpty) return optional ? null : 'Isi password';
  if (password.length < 6) return 'Minimal 6 karakter';
  if (password.length > 8) return 'Maksimal 8 karakter';
  if (!_huruf.hasMatch(password) || !_angka.hasMatch(password)) {
    return 'Gunakan huruf dan angka';
  }
  return null;
}

/// Telepon: opsional, 10–13 angka bila diisi. Spasi, `-`, `()`, dan `+`
/// diabaikan saat menghitung digit.
String? phoneProblem(String phone) {
  if (phone.isEmpty) return null;
  if (!RegExp(r'^\+?[0-9 ()\-]+$').hasMatch(phone)) {
    return 'Nomor telepon tidak valid';
  }
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 10) return 'Minimal 10 angka';
  if (digits.length > 13) return 'Maksimal 13 angka';
  return null;
}

/// Alamat: opsional, tetapi tidak boleh hanya angka/spasi/tanda baca.
String? addressProblem(String address) {
  if (address.isEmpty) return null;
  if (!_huruf.hasMatch(address)) return 'Alamat tidak boleh hanya angka';
  return null;
}

/// Jumlah benih satu semaian: 1–250 (keputusan SA).
String? jumlahBenihProblem(String text) {
  final teks = text.trim();
  if (teks.isEmpty) return 'Isi jumlah benih';
  final jumlah = int.tryParse(teks);
  if (jumlah == null || jumlah <= 0) return 'Jumlah benih harus angka';
  if (jumlah > 250) return 'Maksimal 250 benih';
  return null;
}

/// Jumlah lubang satu meja: 1–250 (keputusan SA).
String? jumlahLubangProblem(String text) {
  final teks = text.trim();
  if (teks.isEmpty) return 'Isi angka lebih dari 0';
  final jumlah = int.tryParse(teks);
  if (jumlah == null || jumlah <= 0) return 'Isi angka lebih dari 0';
  if (jumlah > 250) return 'Maksimal 250 lubang';
  return null;
}
