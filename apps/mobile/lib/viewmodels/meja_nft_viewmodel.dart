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
        name: 'Meja NFT #01',
        status: MejaStatus.aktif,
        capacityUsed: 240,
        capacityTotal: 250,
        batchName: 'Batch #03',
        variety: 'Selada Grand Rapids',
        hss: 28,
      ),
      MejaNft(
        id: '2',
        name: 'Meja NFT #02',
        status: MejaStatus.aktif,
        capacityUsed: 180,
        capacityTotal: 250,
        batchName: 'Batch #04',
        variety: 'Selada Lollo Bionda',
        hss: 15,
      ),
      MejaNft(
        id: '3',
        name: 'Meja NFT #03',
        status: MejaStatus.perawatan,
        capacityTotal: 250,
        maintenanceNote: 'Pembersihan Lumut',
        maintenanceEta: 'Estimasi selesai pembersihan besok sore',
      ),
    ];
  }

  void addMeja(MejaNft newMeja) {
    state = [...state, newMeja];
  }
}

// 1. Data Provider Utama
final mejaNftViewModelProvider =
    StateNotifierProvider<MejaNftViewModel, List<MejaNft>>((ref) {
      return MejaNftViewModel();
    });

// 2. State Filter (Semua, Aktif, Perawatan)
final mejaFilterCategoryProvider = StateProvider<MejaStatus?>((ref) => null);

// 3. State Search Query
final mejaSearchQueryProvider = StateProvider<String>((ref) => '');

// 4. Computed Filtered List
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

// 5. Computed Count Provider untuk Tab Badge
final mejaCountProvider = Provider<Map<String, int>>((ref) {
  final allList = ref.watch(mejaNftViewModelProvider);
  final total = allList.length;
  final aktif = allList.where((e) => e.status == MejaStatus.aktif).length;
  final perawatan = allList
      .where((e) => e.status == MejaStatus.perawatan)
      .length;

  return {'total': total, 'aktif': aktif, 'perawatan': perawatan};
});
