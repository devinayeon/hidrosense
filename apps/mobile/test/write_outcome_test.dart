// Tes aturan: kapan hasil tulis dianggap belum pasti, sehingga kunci dan isian
// harus dipertahankan supaya pengiriman ulang tidak mencatat dua kali.
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/write_outcome.dart';

void main() {
  group('kiriman pertama', () {
    for (final (Object error, expected) in [
      (const ApiException(0, 'NETWORK', 'x'), true),
      (const ApiException(500, 'X', 'x'), true),
      (const ApiException(503, 'HTTP_ERROR', 'x'), true),
      (const ApiException(302, 'HTTP_ERROR', 'x'), true),
      (const ApiException(401, 'SESSION_CHANGED', 'x'), true),
      (const FormatException('rusak'), true),
      (const ApiException(400, 'VALIDATION_ERROR', 'x'), false),
      (const ApiException(401, 'UNAUTHENTICATED', 'x'), false),
      (const ApiException(403, 'FORBIDDEN', 'x'), false),
      (const ApiException(409, 'SALE_EXCEEDS_HARVEST_STOCK', 'x'), false),
      (const ApiException(429, 'RATE_LIMITED', 'x'), false),
    ]) {
      test('$error: belum pasti = $expected', () {
        expect(writeStaysUncertain(error, wasUncertain: false), expected);
      });
    }
  });

  group('setelah kiriman sebelumnya hilang', () {
    // Hanya jawaban API dari jalur tulis yang menjawab nasib kiriman sebelumnya.
    for (final (error, expected) in [
      (const ApiException(400, 'VALIDATION_ERROR', 'x'), false),
      (const ApiException(404, 'SALE_NOT_FOUND', 'x'), false),
      (const ApiException(409, 'SALE_VERSION_CONFLICT', 'x'), false),
      (const ApiException(422, 'HARVEST_NOT_FOUND', 'x'), false),
      // Ditolak sebelum server memeriksa kunci.
      (const ApiException(401, 'UNAUTHENTICATED', 'x'), true),
      (const ApiException(403, 'FORBIDDEN', 'x'), true),
      (const ApiException(408, 'HTTP_ERROR', 'x'), true),
      (const ApiException(426, 'HTTPS_REQUIRED', 'x'), true),
      (const ApiException(429, 'RATE_LIMITED', 'x'), true),
      // Halaman HTML dari proxy atau portal Wi-Fi: server kita tidak terlibat.
      (const ApiException(404, 'HTTP_ERROR', 'x'), true),
      (const ApiException(407, 'HTTP_ERROR', 'x'), true),
      (const ApiException(409, 'HTTP_ERROR', 'x'), true),
      (const ApiException(503, 'HTTP_ERROR', 'x'), true),
    ]) {
      test('${error.status} ${error.code}: belum pasti = $expected', () {
        expect(writeStaysUncertain(error, wasUncertain: true), expected);
      });
    }
  });
}
