import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/penjualan_model.dart';
import '../../viewmodels/catat_penjualan_viewmodel.dart';
import '../../viewmodels/penjualan_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_dropdown_field.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_text_area.dart';
import '../widgets/estimasi_total_card.dart';
import '../widgets/row_button.dart';

class CatatPenjualanBody extends ConsumerStatefulWidget {
  final bool isModal;
  final PenjualanItem? itemToEdit;

  const CatatPenjualanBody({
    super.key,
    this.isModal = false,
    this.itemToEdit,
  });

  /// Static helper untuk menampilkan form dalam format Apple HIG Modal Bottom Sheet
  static Future<bool?> show(BuildContext context, {PenjualanItem? itemToEdit}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CatatPenjualanBody(
        isModal: true,
        itemToEdit: itemToEdit,
      ),
    );
  }

  @override
  ConsumerState<CatatPenjualanBody> createState() => _CatatPenjualanBodyState();
}

class _CatatPenjualanBodyState extends ConsumerState<CatatPenjualanBody> {
  late final TextEditingController _pembeliController;
  late final TextEditingController _tanggalController;
  late final TextEditingController _beratController;
  late final TextEditingController _hargaController;
  late final TextEditingController _catatanController;

  bool get isEdit => widget.itemToEdit != null;

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _pembeliController = TextEditingController(text: item?.pembeli ?? '');

    double initBerat = 0.0;
    if (item != null) {
      final match = RegExp(r'^([0-9.,]+)').firstMatch(item.kuantitas);
      if (match != null) {
        initBerat =
            double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0.0;
      }
    }
    _beratController = TextEditingController(
      text: initBerat > 0 ? formatAngka(initBerat) : '',
    );

    double initHargaPerKg = 0.0;
    if (item != null && initBerat > 0) {
      initHargaPerKg = (item.totalHarga / initBerat).roundToDouble();
    }
    _hargaController = TextEditingController(
      text: initHargaPerKg > 0 ? initHargaPerKg.toInt().toString() : '',
    );

    _catatanController = TextEditingController(text: item?.catatan ?? '');

    final defaultTanggal =
        ref.read(catatPenjualanViewModelProvider).tanggal ?? DateTime.now();
    _tanggalController = TextEditingController(
      text: item?.tanggal ?? formatTanggalIndo(defaultTanggal),
    );

    _pembeliController.addListener(() {
      ref
          .read(catatPenjualanViewModelProvider.notifier)
          .setPembeli(_pembeliController.text);
    });

    _beratController.addListener(() {
      // Terima "2,5" maupun "2.5"
      final text = _beratController.text.replaceAll(',', '.');
      final val = double.tryParse(text) ?? 0.0;
      ref.read(catatPenjualanViewModelProvider.notifier).setBerat(val);
    });

    _hargaController.addListener(() {
      // Ambil hanya digit supaya "20.000" tidak terbaca 20.0
      final digits = _hargaController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final val = double.tryParse(digits) ?? 0.0;
      ref.read(catatPenjualanViewModelProvider.notifier).setHargaPerKg(val);
    });

    if (item != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final formVm = ref.read(catatPenjualanViewModelProvider.notifier);
        formVm.setPembeli(item.pembeli);
        if (initBerat > 0) formVm.setBerat(initBerat);
        if (initHargaPerKg > 0) formVm.setHargaPerKg(initHargaPerKg);
        formVm.setStatus(item.status);
        if (item.catatan != null) formVm.setCatatan(item.catatan!);

        final batchList = ref.read(availableBatchPanenProvider);
        final matchedBatch = batchList.firstWhere(
          (b) =>
              b.id == item.batchPanenId ||
              item.kuantitas.toLowerCase().contains(
                    b.nama.split('-').last.trim().toLowerCase(),
                  ),
          orElse: () => batchList.first,
        );
        formVm.setBatch(matchedBatch);
      });
    }
  }

  @override
  void dispose() {
    _pembeliController.dispose();
    _tanggalController.dispose();
    _beratController.dispose();
    _hargaController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _pickTanggal() async {
    FocusScope.of(context).unfocus();
    final formVm = ref.read(catatPenjualanViewModelProvider.notifier);
    final current = ref.read(catatPenjualanViewModelProvider).tanggal;

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryMint,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      formVm.setTanggal(picked);
      _tanggalController.text = formatTanggalIndo(picked);
    }
  }

  Future<void> _handleSave() async {
    final permissions =
        ref.read(sessionProvider).user?.permissions ?? const <String>[];
    if (!permissions.contains('penjualan:read') ||
        !permissions.contains('penjualan:write')) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final formVm = ref.read(catatPenjualanViewModelProvider.notifier);

    // Sync data teks sebelum submit
    formVm.setPembeli(_pembeliController.text);
    formVm.setCatatan(_catatanController.text);

    if (isEdit) {
      if (!formVm.validateForm()) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              formVm.validationMessage() ?? 'Form belum lengkap.',
            ),
            backgroundColor: AppColors.dangerRed,
          ),
        );
        return;
      }
      final formState = ref.read(catatPenjualanViewModelProvider);
      final komoditasNama =
          formState.selectedBatch?.nama.split('-').last.trim() ?? 'Selada';
      final updatedItem = widget.itemToEdit!.copyWith(
        pembeli: formState.pembeli.trim(),
        tanggal: _tanggalController.text.trim().isEmpty
            ? widget.itemToEdit!.tanggal
            : _tanggalController.text.trim(),
        kuantitas: '${formatAngka(formState.beratKg)} Kg $komoditasNama',
        totalHarga: formState.totalEstimasi,
        status: formState.status!,
        catatan: formState.catatan,
        batchPanenId: formState.selectedBatch?.id,
      );
      ref
          .read(penjualanViewModelProvider.notifier)
          .updatePenjualan(updatedItem);
      HapticFeedback.mediumImpact();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Penjualan berhasil diperbarui!'),
          backgroundColor: AppColors.primaryMint,
        ),
      );
      Navigator.pop(context, true);
      return;
    }

    final success = await formVm.submitPenjualan(ref);
    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Penjualan berhasil dicatat!'),
          backgroundColor: AppColors.primaryMint,
        ),
      );
      Navigator.pop(context, true);
    } else {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            formVm.validationMessage() ??
                'Gagal menyimpan penjualan. Coba lagi.',
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions =
        ref.watch(sessionProvider).user?.permissions ?? const <String>[];
    if (!permissions.contains('penjualan:read') ||
        !permissions.contains('penjualan:write')) {
      return const Center(child: Text('Akses penjualan tidak diizinkan.'));
    }
    final formState = ref.watch(catatPenjualanViewModelProvider);
    final formVm = ref.read(catatPenjualanViewModelProvider.notifier);
    final batchList = ref.watch(availableBatchPanenProvider);

    return Container(
      width: double.infinity,
      height: widget.isModal ? null : double.infinity,
      constraints: widget.isModal
          ? BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9)
          : null,
      decoration: BoxDecoration(
        color: AppColors.canvasWarm,
        borderRadius: widget.isModal
            ? const BorderRadius.vertical(top: Radius.circular(AppRadius.modal))
            : null,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: widget.isModal ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Apple HIG Grabber Handle & Modal Header
          if (widget.isModal) ...[
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xxs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Penjualan' : 'Catat Penjualan',
                    style: AppTypography.title3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),
          ],

          Expanded(
            flex: widget.isModal ? 0 : 1,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Nama Pembeli / Klien
                  CustomInputField(
                    label: 'Nama Pembeli / Klien',
                    hintText: 'Contoh: Supermarket Jaya Makmur',
                    controller: _pembeliController,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Tanggal Transaksi (readOnly, pilih lewat date picker)
                  CustomInputField(
                    label: 'Tanggal Transaksi',
                    hintText: 'Pilih tanggal transaksi',
                    controller: _tanggalController,
                    readOnly: true,
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    onTap: _pickTanggal,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Pilih Hasil Panen
                  CustomDropdownField(
                    label: 'Pilih Hasil Panen',
                    hintText: 'Pilih batch panen yang tersedia di gudang',
                    value: formState.selectedBatch?.nama,
                    items: batchList.map((b) => b.nama).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final selected = batchList.firstWhere(
                        (b) => b.nama == val,
                        orElse: () => batchList.first,
                      );
                      formVm.setBatch(selected);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 4. Baris Berat Jual (Kg) & Harga Per Kg (Rp)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomInputField(
                          label: 'Berat Jual (Kg)',
                          hintText: '0.0',
                          controller: _beratController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: CustomInputField(
                          label: 'Harga Per Kg (Rp)',
                          hintText: 'Rp 20000',
                          controller: _hargaController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 5. Card Estimasi Total (Otomatis)
                  EstimasiTotalCard(totalAmount: formState.totalEstimasi),
                  const SizedBox(height: AppSpacing.md),

                  // 6. Status Pembayaran
                  CustomDropdownField(
                    label: 'Status Pembayaran',
                    hintText: 'Pilih Status (Lunas / Belum Lunas)',
                    value: formState.status == null
                        ? null
                        : (formState.status == StatusPenjualan.lunas
                              ? 'Lunas'
                              : 'Belum Lunas'),
                    items: const ['Lunas', 'Belum Lunas'],
                    onChanged: (val) {
                      if (val == 'Lunas') {
                        formVm.setStatus(StatusPenjualan.lunas);
                      } else if (val == 'Belum Lunas') {
                        formVm.setStatus(StatusPenjualan.belumLunas);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 7. Catatan Transaksi
                  CustomTextArea(
                    label: 'Catatan Transaksi',
                    hintText: 'Keterangan tambahan (Metode transfer, dll)',
                    controller: _catatanController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),

          // 8. Tombol Simpan Penjualan (Apple HIG 52pt pill button)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.canvasWarm,
            child: SafeArea(
              child: RowButton(
                label: isEdit
                    ? 'Simpan Perubahan'
                    : (formState.isLoading
                        ? 'Menyimpan...'
                        : 'Simpan Penjualan'),
                backgroundColor: AppColors.primaryMint,
                textColor: Colors.white,
                borderRadius: AppRadius.pill,
                height: 52,
                onTap: formState.isLoading ? null : _handleSave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
