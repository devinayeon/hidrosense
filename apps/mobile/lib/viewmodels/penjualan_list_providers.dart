import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/business_date.dart';
import '../models/penjualan_model.dart';
import 'penjualan_viewmodel.dart';

final penjualanSearchQueryProvider = StateProvider<String>((ref) => '');

final penjualanFilterCategoryProvider = StateProvider<PenjualanFilterCategory>(
  (ref) => PenjualanFilterCategory.all,
);

final filteredPenjualanListProvider = Provider.autoDispose<List<PenjualanItem>>(
  (ref) {
    final allList = ref.watch(
      penjualanViewModelProvider.select((state) => state.items),
    );
    final query = ref.watch(penjualanSearchQueryProvider).toLowerCase();
    final filter = ref.watch(penjualanFilterCategoryProvider);

    return List.unmodifiable(
      allList.where((item) {
        final matchesSearch =
            item.pembeli.toLowerCase().contains(query) ||
            item.kuantitas.toLowerCase().contains(query);
        final matchesFilter = switch (filter) {
          PenjualanFilterCategory.lunas => item.isLunas,
          PenjualanFilterCategory.belumLunas => !item.isLunas,
          PenjualanFilterCategory.all => true,
        };
        return matchesSearch && matchesFilter;
      }),
    );
  },
);

final totalPendapatanBulanIniProvider = Provider.autoDispose<double>((ref) {
  final list = ref.watch(
    penjualanViewModelProvider.select((state) => state.items),
  );
  final today = jakartaToday(ref.watch(penjualanClockProvider)());
  return list
      .where((item) {
        if (!item.isLunas) return false;
        final date = item.tanggalTransaksi;
        return date != null &&
            date.year == today.year &&
            date.month == today.month;
      })
      .fold(0.0, (sum, item) => sum + item.totalHarga);
});
