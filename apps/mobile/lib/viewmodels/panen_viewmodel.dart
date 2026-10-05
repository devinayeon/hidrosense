import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/panen_model.dart';

enum PanenFilterCategory { all, upcoming, completed }

class PanenViewModel extends StateNotifier<List<PanenItem>> {
  PanenViewModel() : super([]) {
    fetchPanenData();
  }

  Future<void> fetchPanenData() async {
    await Future.delayed(const Duration(milliseconds: 200));
    state = const [
      PanenItem(
        id: '1',
        title: 'Panen Batch #03 (Mendatang)',
        batchName: 'Batch #03',
        mejaInfo: 'Meja NFT #01',
        targetHss: 'Target HSS 38',
        dateText: 'Est. 12 Des 2024',
        processedDate: 'Estimasi 12 Desember 2024',
        resultText: 'Estimasi: ± 250 Kg Selada Grand Rapids',
        status: PanenStatus.estimasi,
        totalWeight: '250 Kg',
        targetWeight: '250 Kg',
        layakPercent: '0%',
        rejectPercent: '0%',
        rejectWeight: '0 Kg',
        asalMejaTanam: 'Meja NFT #01',
        varietas: 'Selada Grand Rapids',
        lamaBudidaya: '38 Hari',
        gradeKualitas: 'Proyeksi Super',
      ),
      PanenItem(
        id: '2',
        title: 'Panen Batch #02',
        batchName: 'Batch #02',
        mejaInfo: 'Meja NFT #03 & #04',
        dateText: '24 Okt 2024',
        processedDate: '24 Oktober 2024',
        resultText: 'Hasil: 480 Kg Selada • Tingkat Reject: 2%',
        status: PanenStatus.selesai,
        totalWeight: '480 Kg',
        targetWeight: '450 Kg',
        layakPercent: '98%',
        rejectPercent: '2%',
        rejectWeight: '10 Kg',
        asalMejaTanam: 'Meja NFT #03 & Meja NFT #04',
        varietas: 'Selada Grand Rapids',
        lamaBudidaya: '36 Hari',
        gradeKualitas: 'Super (Daun tebal, renyah)',
        hargaEstimasi: '20000',
        jumlahLayak: '470',
        jumlahReject: '10',
        catatanPanen: 'Kondisi tanaman sehat dan renyah.',
      ),
      PanenItem(
        id: '3',
        title: 'Panen Batch #01',
        batchName: 'Batch #01',
        mejaInfo: 'Meja NFT #01 & #02',
        dateText: '10 Sep 2024',
        processedDate: '10 September 2024',
        resultText: 'Hasil: 440 Kg Selada • Tingkat Reject: 3.5%',
        status: PanenStatus.selesai,
        totalWeight: '440 Kg',
        targetWeight: '450 Kg',
        layakPercent: '96.5%',
        rejectPercent: '3.5%',
        rejectWeight: '15 Kg',
        asalMejaTanam: 'Meja NFT #01 & Meja NFT #02',
        varietas: 'Selada Grand Rapids',
        lamaBudidaya: '35 Hari',
        gradeKualitas: 'Standard (Daun sedang)',
      ),
    ];
  }

  void addPanen(PanenItem item) {
    state = [item, ...state];
  }

  void updatePanen(PanenItem updatedItem) {
    state = [
      for (final item in state)
        if (item.id == updatedItem.id) updatedItem else item,
    ];
  }
}

final panenViewModelProvider =
    StateNotifierProvider<PanenViewModel, List<PanenItem>>((ref) {
      return PanenViewModel();
    });

final panenFilterCategoryProvider = StateProvider<PanenFilterCategory>(
  (ref) => PanenFilterCategory.all,
);

final filteredPanenListProvider = Provider<List<PanenItem>>((ref) {
  final allList = ref.watch(panenViewModelProvider);
  final filter = ref.watch(panenFilterCategoryProvider);

  switch (filter) {
    case PanenFilterCategory.upcoming:
      return allList.where((item) => item.isEstimasi).toList();
    case PanenFilterCategory.completed:
      return allList.where((item) => !item.isEstimasi).toList();
    case PanenFilterCategory.all:
    default:
      return allList;
  }
});
