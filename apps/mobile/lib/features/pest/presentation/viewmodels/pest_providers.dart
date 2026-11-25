import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/api_client.dart';
import '../../../../viewmodels/damage_viewmodel.dart';
import '../../../../viewmodels/session_viewmodel.dart';
import '../../data/pest_detector.dart';
import '../../data/pest_repository.dart';

final pestRepositoryProvider = Provider<PestRepository>((ref) {
  final repo = PestRepository(ref.watch(apiClientProvider));
  ref.onDispose(repo.close);
  return repo;
});

/// Model dimuat saat halaman pindai dibuka dan dilepas saat tidak ada yang memakainya.
final pestDetectorProvider = FutureProvider.autoDispose<PestDetector>((
  ref,
) async {
  final detector = await PestDetector.load();
  ref.onDispose(detector.dispose);
  return detector;
});

/// Titik masuk deteksi. `watch` menjaga detektor tetap hidup selama halaman pindai terbuka;
/// `read` pada provider autoDispose akan menutup interpreter tepat setelah dimuat.
/// Diganti di tes karena TFLite membutuhkan pustaka native.
final pestDetectFnProvider =
    Provider.autoDispose<Future<PestScanResult> Function(Uint8List)>((ref) {
      final detector = ref.watch(pestDetectorProvider.future);
      return (bytes) async => (await detector).detect(bytes);
    });

/// Batch tanam aktif terbaru pada sebuah meja, atau null bila meja sedang kosong.
final activeTransferResolverProvider =
    Provider<Future<String?> Function(String tableId)>((ref) {
      final repo = ref.watch(damageRepositoryProvider);
      return (tableId) async {
        final active =
            (await repo.listTransfers(
                tableId,
              )).where((t) => t.activePlants > 0).toList()
              ..sort((a, b) => b.transferDate.compareTo(a.transferDate));
        return active.isEmpty ? null : active.first.id;
      };
    });

String pestErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is FormatException) return 'Respons tidak sesuai. Coba lagi.';
  return 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';
}
