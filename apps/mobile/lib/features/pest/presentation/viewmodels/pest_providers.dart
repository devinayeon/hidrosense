import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/api_client.dart';
import '../../../../viewmodels/damage_viewmodel.dart';
import '../../../../viewmodels/session_viewmodel.dart';
import '../../data/pest_detector.dart';
import '../../data/pest_models.dart';
import '../../data/pest_repository.dart';

final pestRepositoryProvider = Provider<PestRepository>((ref) {
  final repo = PestRepository(ref.watch(apiClientProvider));
  ref.onDispose(repo.close);
  return repo;
});

/// Model dimuat saat halaman pindai dibuka dan dilepas saat tidak ada yang memakainya.
final pestDetectorProvider = FutureProvider.autoDispose<PestDetector>((ref) async {
  final detector = await PestDetector.load();
  ref.onDispose(detector.dispose);
  return detector;
});

/// Titik masuk deteksi. `watch` menjaga detektor tetap hidup selama halaman pindai terbuka;
/// `read` pada provider autoDispose akan menutup interpreter tepat setelah dimuat.
/// Diganti di tes karena TFLite membutuhkan pustaka native.
final pestDetectFnProvider = Provider.autoDispose<Future<PestScanResult> Function(Uint8List)>((ref) {
  final detector = ref.watch(pestDetectorProvider.future);
  return (bytes) async => (await detector).detect(bytes);
});

/// Batch tanam aktif terbaru pada sebuah meja, atau null bila meja sedang kosong.
final activeTransferResolverProvider = Provider<Future<String?> Function(String tableId)>((ref) {
  final repo = ref.watch(damageRepositoryProvider);
  return (tableId) async {
    final active = (await repo.listTransfers(tableId)).where((t) => t.activePlants > 0).toList()
      ..sort((a, b) => b.transferDate.compareTo(a.transferDate));
    return active.isEmpty ? null : active.first.id;
  };
});

/// Satu foto pindaian beserta rekomendasi yang lahir dari foto itu.
class ScanEntry {
  const ScanEntry({required this.scan, this.recommendations = const []});

  final PestScanRecord scan;
  final List<PestRecommendation> recommendations;

  /// Status rekomendasi untuk foto ini; null bila belum ada rekomendasi.
  RecommendationStatus? get status =>
      recommendations.isEmpty ? null : recommendations.first.status;
}

/// Pindaian terbaru untuk tab Rawat, sudah dipasangkan dengan status rekomendasinya.
///
/// Status rekomendasi hidup di resource lain (`rekomendasi-obat`), jadi dua daftar
/// digabung lewat `scanId`. Satu foto bisa punya beberapa rekomendasi (satu per hama);
/// status yang ditampilkan adalah rekomendasi pertama.
final pestScansProvider = FutureProvider.autoDispose<List<ScanEntry>>((ref) async {
  final repo = ref.watch(pestRepositoryProvider);
  final scans = await repo.listScans(limit: 20);
  if (scans.items.isEmpty) return const <ScanEntry>[];
  final recommendations = await repo.list(limit: 100);
  final byScan = <String, List<PestRecommendation>>{};
  for (final rec in recommendations.items) {
    final scanId = rec.scanId;
    if (scanId == null) continue;
    byScan.putIfAbsent(scanId, () => <PestRecommendation>[]).add(rec);
  }
  return [
    for (final scan in scans.items)
      ScanEntry(scan: scan, recommendations: byScan[scan.id] ?? const []),
  ];
});

String pestErrorMessage(Object error) {
  if (error is ApiException) return _friendlyPestApiMessage(error);
  if (error is FormatException) return 'Respons tidak sesuai. Coba lagi.';
  return 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';
}

/// Menerjemahkan kode galat backend menjadi kalimat yang bisa ditindaklanjuti
/// petani. Selama ini pesan server dipakai apa adanya, sehingga kendala
/// konfigurasi server (BUG-16) tampil seperti jargon ("belum dikonfigurasi").
String _friendlyPestApiMessage(ApiException error) {
  return switch (error.code) {
    // Kredensial Cloudinary belum diisi di server. Ini bukan salah pengguna
    // maupun HP-nya: foto tidak bisa diunggah sampai pengelola melengkapinya.
    'UPLOAD_NOT_CONFIGURED' =>
      'Penyimpanan foto di server belum aktif. Hubungi pengelola sistem, lalu coba simpan lagi.',
    'UPLOAD_FAILED' =>
      'Foto gagal diunggah ke penyimpanan. Periksa koneksi internet, lalu coba simpan lagi.',
    _ => error.message,
  };
}
