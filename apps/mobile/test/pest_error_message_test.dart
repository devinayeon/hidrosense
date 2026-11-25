// Regresi BUG-16 (sisi mobile): pesan galat unggah foto dulu menampilkan kalimat
// teknis server ("Layanan unggah foto belum dikonfigurasi."). Sekarang kode
// UPLOAD_NOT_CONFIGURED diterjemahkan menjadi langkah yang bisa dilakukan
// petani. Akar masalah kredensial Cloudinary tetap di sisi server.
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/features/pest/presentation/viewmodels/pest_providers.dart';

void main() {
  test('UPLOAD_NOT_CONFIGURED: pesan jelas dan bisa ditindaklanjuti', () {
    final pesan = pestErrorMessage(
      const ApiException(
        503,
        'UPLOAD_NOT_CONFIGURED',
        'Layanan unggah foto belum dikonfigurasi.',
      ),
    );

    expect(pesan, isNot(contains('belum dikonfigurasi')));
    expect(pesan.toLowerCase(), contains('pengelola'));
    expect(pesan.toLowerCase(), contains('coba simpan lagi'));
  });

  test('UPLOAD_FAILED: mengarahkan memeriksa koneksi', () {
    final pesan = pestErrorMessage(
      const ApiException(502, 'UPLOAD_FAILED', 'Unggah foto gagal (502).'),
    );

    expect(pesan.toLowerCase(), contains('koneksi'));
    expect(pesan, isNot(contains('502')));
  });

  test('kode lain tetap memakai pesan server apa adanya', () {
    final pesan = pestErrorMessage(
      const ApiException(422, 'VALIDATION', 'Jumlah tidak sesuai.'),
    );

    expect(pesan, 'Jumlah tidak sesuai.');
  });
}
