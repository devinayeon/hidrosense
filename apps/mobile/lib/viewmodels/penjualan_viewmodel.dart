import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/penjualan_model.dart';

enum PenjualanFilterCategory { all, lunas, belumLunas }

class PenjualanViewModel extends StateNotifier<List<PenjualanItem>> {
  PenjualanViewModel() : super([]) {
    fetchPenjualanData();
  }

  Future<void> fetchPenjualanData() async {
    await Future.delayed(const Duration(milliseconds: 200));
    state = const [
      PenjualanItem(
        id: '1',
        pembeli: 'Supermarket Jaya Makmur',
        tanggal: '12 Nov 2024',
        kuantitas: '50 Kg Selada',
        totalHarga: 1000000,
        status: StatusPenjualan.lunas,
      ),
      PenjualanItem(
        id: '2',
        pembeli: 'Toko Sayur Segar Ibu Ani',
        tanggal: '10 Nov 2024',
        kuantitas: '25 Kg Selada',
        totalHarga: 500000,
        status: StatusPenjualan.belumLunas,
      ),
      PenjualanItem(
        id: '3',
        pembeli: 'Resto Green Salad',
        tanggal: '08 Nov 2024',
        kuantitas: '70 Kg Selada',
        totalHarga: 1400000,
        status: StatusPenjualan.lunas,
      ),
      PenjualanItem(
        id: '4',
        pembeli: 'Catering Healthy Meal',
        tanggal: '05 Nov 2024',
        kuantitas: '40 Kg Selada',
        totalHarga: 800000,
        status: StatusPenjualan.belumLunas,
      ),
    ];
  }

  void addPenjualan(PenjualanItem item) {
    state = [item, ...state];
  }
}

// Provider Data Utama
final penjualanViewModelProvider =
    StateNotifierProvider<PenjualanViewModel, List<PenjualanItem>>((ref) {
      return PenjualanViewModel();
    });

// Provider Query Pencarian
final penjualanSearchQueryProvider = StateProvider<String>((ref) => '');

// Provider Category Filter
final penjualanFilterCategoryProvider = StateProvider<PenjualanFilterCategory>(
  (ref) => PenjualanFilterCategory.all,
);

// Provider List Terfilter
final filteredPenjualanListProvider = Provider<List<PenjualanItem>>((ref) {
  final allList = ref.watch(penjualanViewModelProvider);
  final query = ref.watch(penjualanSearchQueryProvider).toLowerCase();
  final filter = ref.watch(penjualanFilterCategoryProvider);

  return allList.where((item) {
    final matchesSearch =
        item.pembeli.toLowerCase().contains(query) ||
        item.kuantitas.toLowerCase().contains(query);

    final matchesFilter = switch (filter) {
      PenjualanFilterCategory.lunas => item.isLunas,
      PenjualanFilterCategory.belumLunas => !item.isLunas,
      PenjualanFilterCategory.all => true,
    };

    return matchesSearch && matchesFilter;
  }).toList();
});

// Provider Total Pendapatan Bulan Ini (Lunas)
final totalPendapatanBulanIniProvider = Provider<double>((ref) {
  final list = ref.watch(penjualanViewModelProvider);
  return list
      .where((item) => item.isLunas)
      .fold(0.0, (sum, item) => sum + item.totalHarga);
});
