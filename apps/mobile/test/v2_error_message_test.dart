import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';

void main() {
  test('VALIDATION_ERROR teknis diganti kalimat yang bisa ditindaklanjuti', () {
    expect(
      serviceError(
        const ApiException(
          400,
          'VALIDATION_ERROR',
          'Input tidak sesuai kontrak API.',
        ),
      ),
      'Ada isian yang belum sesuai. Periksa kembali data yang Anda masukkan.',
    );
  });

  test('pesan validasi yang sudah jelas tidak diubah', () {
    expect(
      serviceError(
        const ApiException(
          400,
          'VALIDATION_ERROR',
          'Tanggal panen tidak boleh di masa depan.',
        ),
      ),
      'Tanggal panen tidak boleh di masa depan.',
    );
  });

  test('detail field dari backend dipakai sebagai pesan yang spesifik', () {
    expect(
      serviceError(
        const ApiException(
          400,
          'VALIDATION_ERROR',
          'Input tidak sesuai kontrak API.',
          details: [
            ApiFieldError(field: 'jumlah_lubang', message: 'Maksimal 1000.'),
          ],
        ),
      ),
      'Ada isian yang belum sesuai (jumlah lubang): Maksimal 1000.',
    );
  });

  test('tanpa detail field, kalimat umum tetap dipakai', () {
    expect(
      serviceError(
        const ApiException(
          400,
          'VALIDATION_ERROR',
          'Input tidak sesuai kontrak API.',
          details: [],
        ),
      ),
      'Ada isian yang belum sesuai. Periksa kembali data yang Anda masukkan.',
    );
  });

  test('header sinkronisasi yang rusak diberi kalimat pengguna', () {
    expect(
      serviceError(
        const ApiException(
          400,
          'VALIDATION_ERROR',
          'Header sinkronisasi tidak valid.',
        ),
      ),
      'Sinkronisasi data gagal. Coba lagi sebentar.',
    );
  });
}
