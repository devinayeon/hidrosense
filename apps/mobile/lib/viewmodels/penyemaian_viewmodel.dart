import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/seeding_batch_model.dart';

class PenyemaianViewModel extends StateNotifier<List<SeedingBatch>> {
  PenyemaianViewModel() : super([]) {
    fetchSeedingData();
  }

  Future<void> fetchSeedingData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    state = [
      SeedingBatch(
        id: '1',
        batchName: 'Batch #04',
        variety: 'Selada Grand Rapids',
        dateText: '01 Nov 2024',
        seedCount: 400,
        hss: 14,
        statusLabel: 'Siap Pindah Besok',
        note: 'Hampir 15 HSS - Rekomendasi pindah ke meja pembesaran.',
      ),
      SeedingBatch(
        id: '2',
        batchName: 'Batch #05',
        variety: 'Selada RZ Lollo Bionda',
        dateText: '08 Nov 2024',
        seedCount: 600,
        hss: 7,
        statusLabel: 'Fase Pembibitan',
      ),
    ];
  }
}

final penyemaianViewModelProvider =
    StateNotifierProvider<PenyemaianViewModel, List<SeedingBatch>>((ref) {
      return PenyemaianViewModel();
    });
