import 'api_client.dart';

/// Status yang hanya bisa datang dari jalur tulis server, setelah kunci diperiksa.
const _answeredByWritePath = {400, 404, 409, 422};

/// Apakah hasil sebuah tulis masih belum pasti setelah gagal dengan [error]?
///
/// Belum pasti berarti data mungkin sudah tersimpan di server, jadi kunci dan
/// isian harus dipertahankan: jaringan putus, jawaban rusak, atau server gagal.
///
/// Pada kiriman pertama, penolakan 4xx berarti tidak ada yang tersimpan. Bila
/// kiriman sebelumnya hilang ([wasUncertain]), hanya jawaban API dari jalur tulis
/// yang menjawab nasibnya. Jawaban lain (401, 403, 408, 426, 429, atau halaman
/// HTML dari proxy dan portal Wi-Fi) datang sebelum kunci diperiksa.
bool writeStaysUncertain(Object error, {required bool wasUncertain}) {
  if (error is! ApiException ||
      error.code == 'SESSION_CHANGED' ||
      error.status < 400 ||
      error.status >= 500) {
    return true;
  }
  if (!wasUncertain) return false;
  return error.code == 'HTTP_ERROR' ||
      !_answeredByWritePath.contains(error.status);
}
