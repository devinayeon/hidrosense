import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/business_date.dart';
import '../core/formatting.dart';
import '../data/models/sale_record.dart';
import '../models/penjualan_model.dart';
import 'penjualan_viewmodel.dart';
import 'session_viewmodel.dart';

class CatatPenjualanState {
  const CatatPenjualanState({
    this.pembeli = '',
    this.tanggal,
    this.selectedBatch,
    this.beratKg = 0.0,
    this.hargaPerKg = 0.0,
    this.status,
    this.catatan = '',
    this.isLoading = false,
    this.saveError,
  });

  final String pembeli;
  final DateTime? tanggal;
  final BatchPanen? selectedBatch;
  final double beratKg;
  final double hargaPerKg;
  final StatusPenjualan? status;
  final String catatan;
  final bool isLoading;
  final String? saveError;

  double get totalEstimasi => beratKg * hargaPerKg;

  CatatPenjualanState copyWith({
    String? pembeli,
    DateTime? tanggal,
    BatchPanen? selectedBatch,
    bool clearBatch = false,
    double? beratKg,
    double? hargaPerKg,
    StatusPenjualan? status,
    String? catatan,
    bool? isLoading,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return CatatPenjualanState(
      pembeli: pembeli ?? this.pembeli,
      tanggal: tanggal ?? this.tanggal,
      selectedBatch: clearBatch ? null : (selectedBatch ?? this.selectedBatch),
      beratKg: beratKg ?? this.beratKg,
      hargaPerKg: hargaPerKg ?? this.hargaPerKg,
      status: status ?? this.status,
      catatan: catatan ?? this.catatan,
      isLoading: isLoading ?? this.isLoading,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
    );
  }
}

class CatatPenjualanViewModel extends StateNotifier<CatatPenjualanState> {
  CatatPenjualanViewModel({DateTime? initialDate})
    : super(CatatPenjualanState(tanggal: initialDate ?? jakartaToday()));

  void setPembeli(String val) => state = state.copyWith(pembeli: val);
  void setTanggal(DateTime val) => state = state.copyWith(tanggal: val);
  void setBatch(BatchPanen? val) =>
      state = state.copyWith(selectedBatch: val, clearBatch: val == null);
  void setBerat(double val) => state = state.copyWith(beratKg: val);
  void setHargaPerKg(double val) => state = state.copyWith(hargaPerKg: val);
  void setStatus(StatusPenjualan? val) {
    state = state.copyWith(status: val, clearSaveError: true);
  }

  void setCatatan(String val) => state = state.copyWith(catatan: val);

  String? validationMessage() {
    if (state.pembeli.trim().isEmpty) {
      return 'Nama pembeli wajib diisi.';
    }
    if (state.pembeli.trim().length > 100) {
      return 'Nama pembeli maksimal 100 karakter.';
    }
    if (state.tanggal == null) {
      return 'Tanggal transaksi wajib dipilih.';
    }
    if (apiDate(state.tanggal!).compareTo(apiDate(jakartaToday())) > 0) {
      return 'Tanggal transaksi tidak boleh di masa depan.';
    }
    if (state.selectedBatch == null) {
      return 'Pilih hasil panen terlebih dahulu.';
    }
    final harvestDate = state.selectedBatch!.tanggalPanen;
    if (harvestDate != null &&
        apiDate(state.tanggal!).compareTo(harvestDate) < 0) {
      return 'Tanggal transaksi mendahului tanggal panen.';
    }
    if (state.beratKg <= 0) {
      return 'Berat jual harus lebih dari 0 Kg.';
    }
    final weightScaled = state.beratKg * 100;
    if ((weightScaled - weightScaled.round()).abs() > 1e-6) {
      return 'Berat jual maksimal dua angka desimal.';
    }
    if (state.beratKg > state.selectedBatch!.stokTersedia) {
      return 'Berat melebihi stok tersedia '
          '(${formatAngka(state.selectedBatch!.stokTersedia)} Kg).';
    }
    if (state.hargaPerKg <= 0) {
      return 'Harga per Kg harus lebih dari 0.';
    }
    final priceScaled = state.hargaPerKg * 100;
    if ((priceScaled - priceScaled.round()).abs() > 1e-6) {
      return 'Harga per Kg maksimal dua angka desimal.';
    }
    if (state.status == null) {
      return 'Status pembayaran wajib dipilih.';
    }
    if (state.catatan.length > 1000) {
      return 'Catatan transaksi maksimal 1000 karakter.';
    }
    return null;
  }

  bool validateForm() => validationMessage() == null;

  Future<bool> submitPenjualan(WidgetRef ref, {PenjualanItem? edit}) async {
    if (edit != null && !edit.canEdit) {
      state = state.copyWith(
        isLoading: false,
        saveError: 'Transaksi multi-batch belum dapat diedit dari aplikasi.',
      );
      return false;
    }
    final message = validationMessage();
    if (message != null) {
      state = state.copyWith(isLoading: false, saveError: message);
      return false;
    }

    final note = state.catatan.trim();
    final draft = SalesDraft(
      date: apiDate(state.tanggal!),
      buyer: state.pembeli.trim(),
      status: state.status == StatusPenjualan.lunas ? 'lunas' : 'belum_lunas',
      harvestId: state.selectedBatch!.id,
      quantity: state.beratKg,
      price: state.hargaPerKg,
      note: note.isEmpty ? null : note,
    );

    state = state.copyWith(
      isLoading: true,
      saveError: null,
      clearSaveError: true,
    );
    try {
      final notifier = ref.read(penjualanViewModelProvider.notifier);
      if (edit == null) {
        await notifier.createSale(draft);
      } else {
        await notifier.updateSale(edit, draft);
      }
      if (!mounted) return true;
      state = state.copyWith(
        isLoading: false,
        saveError: null,
        clearSaveError: true,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(isLoading: false, saveError: serviceError(error));
      return false;
    }
  }
}

final catatPenjualanViewModelProvider =
    StateNotifierProvider.autoDispose<
      CatatPenjualanViewModel,
      CatatPenjualanState
    >((ref) {
      return CatatPenjualanViewModel();
    });
