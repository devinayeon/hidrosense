// lib/viewmodels/baris_tanam_viewmodel.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/baris_tanam_model.dart';
import '../models/laporan_kerusakan_model.dart';

enum BarisFilterCategory { all, good, damaged }

class BarisTanamViewModel extends StateNotifier<List<BarisTanam>> {
  BarisTanamViewModel() : super([]) {
    fetchBarisData();
  }

  Future<void> fetchBarisData() async {
    await Future.delayed(const Duration(milliseconds: 200));
    state = const [
      BarisTanam(
        id: '1',
        name: 'Baris A',
        holesRange: 'Lubang 1-50',
        totalBibit: 50,
        healthyCount: 50,
        failedCount: 0,
        hss: 28,
      ),
      BarisTanam(
        id: '2',
        name: 'Baris B',
        holesRange: 'Lubang 51-100',
        totalBibit: 50,
        healthyCount: 46,
        failedCount: 4,
        hss: 28,
      ),
      BarisTanam(
        id: '3',
        name: 'Baris C',
        holesRange: 'Lubang 101-150',
        totalBibit: 50,
        healthyCount: 50,
        failedCount: 0,
        hss: 28,
      ),
    ];
  }

  // Method untuk mencatat laporan kerusakan baru & memperbarui state baris
  void submitLaporanKerusakan(LaporanKerusakan laporan) {
    state = [
      for (final baris in state)
        if (baris.id == laporan.barisId)
          baris.copyWith(
            failedCount: baris.failedCount + laporan.jumlahRusak,
            healthyCount:
                (baris.totalBibit - (baris.failedCount + laporan.jumlahRusak))
                    .clamp(0, baris.totalBibit),
          )
        else
          baris,
    ];
  }
}

final barisTanamViewModelProvider =
    StateNotifierProvider<BarisTanamViewModel, List<BarisTanam>>((ref) {
      return BarisTanamViewModel();
    });

final barisFilterCategoryProvider = StateProvider<BarisFilterCategory>(
  (ref) => BarisFilterCategory.all,
);

final filteredBarisTanamListProvider = Provider<List<BarisTanam>>((ref) {
  final allList = ref.watch(barisTanamViewModelProvider);
  final filter = ref.watch(barisFilterCategoryProvider);

  switch (filter) {
    case BarisFilterCategory.good:
      return allList.where((item) => item.isPerfect).toList();
    case BarisFilterCategory.damaged:
      return allList.where((item) => !item.isPerfect).toList();
    case BarisFilterCategory.all:
    default:
      return allList;
  }
});
