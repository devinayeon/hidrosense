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
        totalHss: 15,
        healthyCount: 382,
        healthyPhase: 'Fase daun sejati 4',
        damagedCount: 18,
        damagedNote: 'Kerdil/Gagal tumbuh',
        materials: [
          '400 butir Benih Selada Grand Rapids',
          '1 Lembar Rockwool (18 lubang tanam per baris)',
        ],
        statusLabel: 'Siap Pindah Besok',
        note: 'Disemai di rak tingkat 2, terpapar cahaya p...',
      ),
      SeedingBatch(
        id: '2',
        batchName: 'Batch #05',
        variety: 'Selada RZ Lollo Bionda',
        dateText: '08 Nov 2024',
        seedCount: 600,
        hss: 7,
        totalHss: 15,
        healthyCount: 580,
        healthyPhase: 'Fase daun sejati 2',
        damagedCount: 20,
        damagedNote: 'Gagal berkecambah',
        materials: [
          '600 butir Benih Selada RZ Lollo Bionda',
          '1.5 Lembar Rockwool',
        ],
        statusLabel: 'Fase Pembibitan',
      ),
    ];
  }

  // Tambah Batch Baru
  void addBatch(SeedingBatch newBatch) {
    state = [...state, newBatch];
  }

  // Update Batch yang Ada
  void updateBatch(SeedingBatch updatedBatch) {
    state = [
      for (final item in state)
        if (item.id == updatedBatch.id) updatedBatch else item,
    ];
  }
}

// 1. Provider State Data Penyemaian Utama
final penyemaianViewModelProvider =
    StateNotifierProvider<PenyemaianViewModel, List<SeedingBatch>>((ref) {
      return PenyemaianViewModel();
    });

// 2. Provider State Query Pencarian
final seedingSearchQueryProvider = StateProvider<String>((ref) => '');

// 3. Provider Computed Hasil Filter (Berdasarkan Batch Name & Variety)
final filteredSeedingListProvider = Provider<List<SeedingBatch>>((ref) {
  final allList = ref.watch(penyemaianViewModelProvider);
  final query = ref.watch(seedingSearchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) {
    return allList;
  }

  return allList.where((item) {
    final matchBatch = item.batchName.toLowerCase().contains(query);
    final matchVariety = item.variety.toLowerCase().contains(query);
    return matchBatch || matchVariety;
  }).toList();
});
