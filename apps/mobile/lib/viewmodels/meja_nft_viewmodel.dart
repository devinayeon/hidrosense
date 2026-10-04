// lib/viewmodels/meja_nft_viewmodel.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meja_nft_model.dart';

class MejaNftViewModel extends StateNotifier<List<MejaNft>> {
  MejaNftViewModel() : super([]) {
    fetchMejaData();
  }

  Future<void> fetchMejaData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    state = const [
      MejaNft(
        id: '1',
        name: 'Meja Utama NFT #01',
        systemType: 'Sistem NFT',
        location: 'Lokasi Green House Barat',
        status: MejaStatus.aktif,
        capacityUsed: 240,
        capacityTotal: 250,
        healthyCount: 240,
        failedCount: 10,
        batchName: 'Batch #03',
        variety: 'Selada Grand Rapids',
        hss: 28,
        estimatedHarvestDate: '12 Des 2024 (± 10 hari lagi)',
        notes: 'Pompa Shimizu 128W, Pipa Rucika 3 Inch',
      ),
      MejaNft(
        id: '2',
        name: 'Meja NFT #02',
        systemType: 'Sistem NFT',
        location: 'Lokasi Green House Barat',
        status: MejaStatus.aktif,
        capacityUsed: 180,
        capacityTotal: 250,
        healthyCount: 175,
        failedCount: 5,
        batchName: 'Batch #04',
        variety: 'Selada Lollo Bionda',
        hss: 15,
        estimatedHarvestDate: '25 Des 2024 (± 23 hari lagi)',
      ),
      MejaNft(
        id: '3',
        name: 'Meja NFT #03',
        systemType: 'Sistem NFT',
        location: 'Lokasi Green House Timur',
        status: MejaStatus.perawatan,
        capacityTotal: 250,
        maintenanceNote: 'Pembersihan Lumut',
        maintenanceEta: 'Estimasi selesai pembersihan besok sore',
      ),
    ];
  }

  // Aksi Tambah Meja Baru
  void addMeja(MejaNft newMeja) {
    state = [...state, newMeja];
  }

  // Aksi Update / Edit Meja
  void updateMeja(MejaNft updatedMeja) {
    state = [
      for (final item in state)
        if (item.id == updatedMeja.id) updatedMeja else item,
    ];
  }
}

final mejaNftViewModelProvider =
    StateNotifierProvider<MejaNftViewModel, List<MejaNft>>((ref) {
      return MejaNftViewModel();
    });

final mejaFilterCategoryProvider = StateProvider<MejaStatus?>((ref) => null);
final mejaSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredMejaNftListProvider = Provider<List<MejaNft>>((ref) {
  final allList = ref.watch(mejaNftViewModelProvider);
  final filter = ref.watch(mejaFilterCategoryProvider);
  final query = ref.watch(mejaSearchQueryProvider).trim().toLowerCase();

  return allList.where((item) {
    final matchesFilter = filter == null || item.status == filter;
    final matchesQuery =
        query.isEmpty ||
        item.name.toLowerCase().contains(query) ||
        (item.variety?.toLowerCase().contains(query) ?? false) ||
        (item.batchName?.toLowerCase().contains(query) ?? false);

    return matchesFilter && matchesQuery;
  }).toList();
});

final mejaCountProvider = Provider<Map<String, int>>((ref) {
  final allList = ref.watch(mejaNftViewModelProvider);
  final total = allList.length;
  final aktif = allList.where((e) => e.status == MejaStatus.aktif).length;
  final perawatan = allList
      .where((e) => e.status == MejaStatus.perawatan)
      .length;

  return {'total': total, 'aktif': aktif, 'perawatan': perawatan};
});
