import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/penjualan_model.dart';
import 'penjualan_viewmodel.dart';

const List<String> _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Format tanggal bahasa Indonesia TANPA bergantung pada
/// initializeDateFormatting('id_ID') sehingga tidak bisa melempar error.
/// singkat = false -> "06 Oktober 2026", singkat = true -> "06 Okt 2026"
String formatTanggalIndo(DateTime d, {bool singkat = false}) {
  final hari = d.day.toString().padLeft(2, '0');
  final bulan = _namaBulan[d.month - 1];
  final bulanText = singkat && bulan.length > 3 ? bulan.substring(0, 3) : bulan;
  return '$hari $bulanText ${d.year}';
}

/// 50.0 -> "50", 2.5 -> "2.5"
String formatAngka(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

// State untuk Form Catat Penjualan
class CatatPenjualanState {
  final String pembeli;
  final DateTime? tanggal;
  final BatchPanen? selectedBatch;
  final double beratKg;
  final double hargaPerKg;
  final StatusPenjualan? status;
  final String catatan;
  final bool isLoading;

  const CatatPenjualanState({
    this.pembeli = '',
    this.tanggal,
    this.selectedBatch,
    this.beratKg = 0.0,
    this.hargaPerKg = 0.0,
    this.status,
    this.catatan = '',
    this.isLoading = false,
  });

  // Estimasi Total Otomatis = Berat (Kg) * Harga Per Kg
  double get totalEstimasi => beratKg * hargaPerKg;

  CatatPenjualanState copyWith({
    String? pembeli,
    DateTime? tanggal,
    BatchPanen? selectedBatch,
    double? beratKg,
    double? hargaPerKg,
    StatusPenjualan? status,
    String? catatan,
    bool? isLoading,
  }) {
    return CatatPenjualanState(
      pembeli: pembeli ?? this.pembeli,
      tanggal: tanggal ?? this.tanggal,
      selectedBatch: selectedBatch ?? this.selectedBatch,
      beratKg: beratKg ?? this.beratKg,
      hargaPerKg: hargaPerKg ?? this.hargaPerKg,
      status: status ?? this.status,
      catatan: catatan ?? this.catatan,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CatatPenjualanViewModel extends StateNotifier<CatatPenjualanState> {
  // Tanggal default = hari ini (sesuai hint "Hari ini" di form)
  CatatPenjualanViewModel()
    : super(CatatPenjualanState(tanggal: DateTime.now()));

  void setPembeli(String val) => state = state.copyWith(pembeli: val);
  void setTanggal(DateTime val) => state = state.copyWith(tanggal: val);
  void setBatch(BatchPanen? val) => state = state.copyWith(selectedBatch: val);
  void setBerat(double val) => state = state.copyWith(beratKg: val);
  void setHargaPerKg(double val) => state = state.copyWith(hargaPerKg: val);
  void setStatus(StatusPenjualan? val) => state = state.copyWith(status: val);
  void setCatatan(String val) => state = state.copyWith(catatan: val);

  /// Mengembalikan pesan error spesifik, atau null jika form valid.
  String? validationMessage() {
    if (state.pembeli.trim().isEmpty) {
      return 'Nama pembeli wajib diisi.';
    }
    if (state.tanggal == null) {
      return 'Tanggal transaksi wajib dipilih.';
    }
    if (state.selectedBatch == null) {
      return 'Pilih hasil panen terlebih dahulu.';
    }
    if (state.beratKg <= 0) {
      return 'Berat jual harus lebih dari 0 Kg.';
    }
    if (state.beratKg > state.selectedBatch!.stokTersedia) {
      return 'Berat melebihi stok tersedia '
          '(${formatAngka(state.selectedBatch!.stokTersedia)} Kg).';
    }
    if (state.hargaPerKg <= 0) {
      return 'Harga per Kg harus lebih dari 0.';
    }
    if (state.status == null) {
      return 'Status pembayaran wajib dipilih.';
    }
    return null;
  }

  bool validateForm() => validationMessage() == null;

  Future<bool> submitPenjualan(WidgetRef ref) async {
    // 1. Cek validasi terlebih dahulu
    if (!validateForm()) {
      state = state.copyWith(isLoading: false);
      return false;
    }

    // 2. Jika validasi lolos, set isLoading = true
    state = state.copyWith(isLoading: true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final formattedTanggal = formatTanggalIndo(state.tanggal!, singkat: true);
      final komoditasNama =
          state.selectedBatch?.nama.split('-').last.trim() ?? 'Selada';

      final newItem = PenjualanItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        pembeli: state.pembeli.trim(),
        tanggal: formattedTanggal,
        kuantitas: '${formatAngka(state.beratKg)} Kg $komoditasNama',
        totalHarga: state.totalEstimasi,
        status: state.status!,
        catatan: state.catatan,
        batchPanenId: state.selectedBatch?.id,
      );

      ref.read(penjualanViewModelProvider.notifier).addPenjualan(newItem);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }
}

// Provider Form
final catatPenjualanViewModelProvider =
    StateNotifierProvider.autoDispose<
      CatatPenjualanViewModel,
      CatatPenjualanState
    >((ref) {
      return CatatPenjualanViewModel();
    });

// Provider Dummy Data Batch Panen
final availableBatchPanenProvider = Provider<List<BatchPanen>>((ref) {
  return const [
    BatchPanen(
      id: 'b1',
      nama: 'Batch #04 - Selada Grand Rapids',
      stokTersedia: 120.0,
    ),
    BatchPanen(
      id: 'b2',
      nama: 'Batch #05 - Romaine Lettuce',
      stokTersedia: 80.0,
    ),
    BatchPanen(id: 'b3', nama: 'Batch #06 - Butterhead', stokTersedia: 50.0),
  ];
});
