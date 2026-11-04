import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/business_date.dart';
import '../../core/formatting.dart';
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

  const CatatPenjualanBody({super.key, this.isModal = false, this.itemToEdit});

  /// Static helper untuk menampilkan form dalam format Apple HIG Modal Bottom Sheet
  static Future<bool?> show(BuildContext context, {PenjualanItem? itemToEdit}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CatatPenjualanBody(isModal: true, itemToEdit: itemToEdit),
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
  bool _batchSyncScheduled = false;

  bool get isEdit => widget.itemToEdit != null;
  bool get _headerOnly =>
      widget.itemToEdit != null && widget.itemToEdit!.details.length != 1;

  PenjualanLine? get _editLine {
    final item = widget.itemToEdit;
    return item != null && item.details.length == 1
        ? item.details.single
        : null;
  }

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    final line = _editLine;
    final formVm = ref.read(catatPenjualanViewModelProvider.notifier);

    _pembeliController = TextEditingController(text: item?.pembeli ?? '');

    final initBerat = line?.jumlahKg ?? 0.0;
    _beratController = TextEditingController(
      text: initBerat > 0 ? formatAngka(initBerat) : '',
    );

    final initHargaPerKg = line?.hargaPerKgWire ?? '';
    _hargaController = TextEditingController(text: initHargaPerKg);

    _catatanController = TextEditingController(text: item?.catatan ?? '');

    final defaultTanggal = item?.tanggalTransaksi ?? jakartaToday();
    _tanggalController = TextEditingController(
      text: formatTanggalIndo(defaultTanggal),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final formVm = ref.read(catatPenjualanViewModelProvider.notifier);
      formVm.setPembeli(item?.pembeli ?? '');
      formVm.setTanggal(defaultTanggal);
      if (initBerat > 0) formVm.setBerat(initBerat);
      if (initHargaPerKg.isNotEmpty) {
        formVm.setHargaPerKgText(initHargaPerKg);
      }
      formVm.setCatatan(item?.catatan ?? '');
      if (item != null) formVm.setStatus(item.status);
      if (item != null && line != null) formVm.setBatch(_fallbackBatch(line));
    });

    _pembeliController.addListener(() {
      formVm.setPembeli(_pembeliController.text);
    });

    _beratController.addListener(() {
      // Terima "2,5" maupun "2.5"
      final text = _beratController.text.replaceAll(',', '.');
      final val = double.tryParse(text) ?? 0.0;
      formVm.setBerat(val);
    });

    _hargaController.addListener(() {
      // Simpan teks asli agar dua angka desimal tidak hilang saat dikirim.
      formVm.setHargaPerKgText(_hargaController.text);
    });
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

  BatchPanen _fallbackBatch(PenjualanLine line) {
    final date = DateTime.parse(line.tanggalPanen);
    return BatchPanen(
      id: line.idPanen,
      nama:
          'Panen #${line.idPanen} · '
          '${formatTanggalIndo(date, singkat: true)}',
      stokTersedia: line.jumlahKg,
      tanggalPanen: line.tanggalPanen,
    );
  }

  List<BatchPanen> _batchesForForm(List<BatchPanen> allBatches) {
    final item = widget.itemToEdit;
    final line = _editLine;
    if (item == null || line == null) {
      final available = allBatches
          .where((batch) => batch.stokTersedia > 0)
          .toList();
      final selected = ref.read(catatPenjualanViewModelProvider).selectedBatch;
      if (selected != null &&
          !available.any((batch) => batch.id == selected.id)) {
        available.insert(0, selected);
      }
      return List.unmodifiable(available);
    }

    final matched = allBatches.where((batch) => batch.id == line.idPanen);
    final current = matched.isEmpty
        ? _fallbackBatch(line)
        : matched.first.copyWith(
            stokTersedia: _roundKg(matched.first.stokTersedia + line.jumlahKg),
          );
    return List.unmodifiable([
      current,
      ...allBatches.where(
        (batch) => batch.id != line.idPanen && batch.stokTersedia > 0,
      ),
    ]);
  }

  void _scheduleEditBatchSync(List<BatchPanen> batches) {
    final line = _editLine;
    if (line == null || batches.isEmpty) return;
    final selected = ref.read(catatPenjualanViewModelProvider).selectedBatch;
    if (selected != null && selected.id != line.idPanen) return;
    final target = batches.firstWhere(
      (batch) => batch.id == line.idPanen,
      orElse: () => batches.first,
    );
    if (selected != null &&
        selected.id == target.id &&
        selected.nama == target.nama &&
        (selected.stokTersedia - target.stokTersedia).abs() < 0.001) {
      return;
    }
    if (_batchSyncScheduled) return;
    _batchSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _batchSyncScheduled = false;
      if (!mounted) return;
      ref.read(catatPenjualanViewModelProvider.notifier).setBatch(target);
    });
  }

  double _roundKg(double weight) => double.parse(weight.toStringAsFixed(2));

  Future<void> _pickTanggal() async {
    FocusScope.of(context).unfocus();
    final formVm = ref.read(catatPenjualanViewModelProvider.notifier);
    final current = ref.read(catatPenjualanViewModelProvider).tanggal;
    final today = jakartaToday();
    final initial = current == null || current.isAfter(today) ? today : current;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: today,
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
    formVm.setHargaPerKgText(_hargaController.text);

    if (isEdit && !widget.itemToEdit!.canEdit) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Transaksi ini belum dapat diedit. Muat ulang daftar penjualan.',
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      return;
    }

    final success = await formVm.submitPenjualan(ref, edit: widget.itemToEdit);
    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Penjualan berhasil diperbarui!'
                : 'Penjualan berhasil dicatat!',
          ),
          backgroundColor: AppColors.primaryMint,
        ),
      );
      Navigator.pop(context, true);
    } else {
      final message =
          ref.read(catatPenjualanViewModelProvider).saveError ??
          formVm.validationMessage() ??
          'Gagal menyimpan penjualan. Coba lagi.';
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.dangerRed),
      );
    }
  }

  Widget _buildMultiBatchNotice(PenjualanItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.accentMintSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.layers_outlined,
            size: 20,
            color: AppColors.primaryDarkTeal,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaksi ${item.details.length} batch panen',
                  style: AppTypography.subheadline.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rincian batch, berat, dan harga tidak diubah. '
                  'Hanya data transaksi di atas yang diperbarui.',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total ${item.kuantitas} · ${formatRupiah(item.totalHarga)}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final batchList = _batchesForForm(ref.watch(batchPanenListProvider));
    _scheduleEditBatchSync(batchList);

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

                  // 3. Pilih Hasil Panen — hanya untuk transaksi satu batch.
                  if (!_headerOnly) ...[
                    CustomDropdownField(
                      label: 'Pilih Hasil Panen',
                      hintText: 'Pilih batch panen yang tersedia di gudang',
                      value: formState.selectedBatch?.nama,
                      items: batchList.map((batch) => batch.nama).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final selected = batchList.firstWhere(
                          (batch) => batch.nama == val,
                          orElse: () => batchList.first,
                        );
                        formVm.setBatch(selected);
                      },
                    ),
                    if (formState.selectedBatch != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Stok tersedia: '
                        '${formatAngka(formState.selectedBatch!.stokTersedia)} Kg',
                        style: AppTypography.footnote.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ] else
                    _buildMultiBatchNotice(widget.itemToEdit!),
                  if (isEdit && !widget.itemToEdit!.canEdit) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Data versi transaksi tidak tersedia. Muat ulang daftar '
                      'sebelum mengedit.',
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.dangerRed,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),

                  // 4. Baris Berat Jual (Kg) & Harga Per Kg (Rp)
                  if (!_headerOnly)
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
                            hintText: 'Rp 20000.50',
                            controller: _hargaController,
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
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(height: AppSpacing.md),

                  // 5. Card Estimasi Total (Otomatis)
                  if (!_headerOnly) ...[
                    EstimasiTotalCard(totalAmount: formState.totalEstimasi),
                    const SizedBox(height: AppSpacing.md),
                  ],

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
                label: formState.isLoading
                    ? 'Menyimpan...'
                    : (isEdit ? 'Simpan Perubahan' : 'Simpan Penjualan'),
                backgroundColor: AppColors.primaryMint,
                textColor: Colors.white,
                borderRadius: AppRadius.pill,
                height: 52,
                onTap:
                    formState.isLoading ||
                        (isEdit && !widget.itemToEdit!.canEdit)
                    ? null
                    : _handleSave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
