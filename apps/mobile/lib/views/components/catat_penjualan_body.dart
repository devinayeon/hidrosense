import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/business_date.dart';
import '../../core/formatting.dart';
import '../../models/penjualan_model.dart';
import '../../viewmodels/catat_penjualan_viewmodel.dart';
import '../../viewmodels/penjualan_mappers.dart';
import '../../viewmodels/penjualan_viewmodel.dart';
import '../../viewmodels/sale_command.dart';
import '../../viewmodels/sale_form_seed.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../theme/app_theme.dart';
import '../widgets/sale_date_picker.dart';
import '../widgets/sale_uncertain_notice.dart';
import 'catat_penjualan_fields.dart';

class CatatPenjualanBody extends ConsumerStatefulWidget {
  final PenjualanItem? itemToEdit;

  const CatatPenjualanBody({super.key, this.itemToEdit});

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
  bool _batchRestored = false;

  bool get isEdit => widget.itemToEdit != null;

  String get _saleTarget => widget.itemToEdit?.id ?? saleCreateTarget;

  SaleCommand? get _pendingCommand =>
      ref.read(penjualanViewModelProvider.notifier).uncertainCommand;

  SaleCommand? get _pendingForThisForm {
    final pending = _pendingCommand;
    return pending?.target == _saleTarget ? pending : null;
  }

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
    final seed = SaleFormSeed.from(item, _pendingForThisForm, jakartaToday());
    _batchRestored = seed.restoredBatch != null;

    _pembeliController = TextEditingController(text: seed.buyer);
    _beratController = TextEditingController(
      text: seed.weight > 0 ? formatAngka(seed.weight) : '',
    );
    _hargaController = TextEditingController(text: seed.priceText);
    _catatanController = TextEditingController(text: seed.note);
    _tanggalController = TextEditingController(
      text: formatTanggalIndo(seed.date),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      formVm.applySeed(seed);
      if (seed.restoredBatch != null) {
        formVm.setBatch(seed.restoredBatch);
      } else if (item != null && line != null) {
        formVm.setBatch(fallbackSaleBatch(line));
      }
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

  void _scheduleEditBatchSync(List<BatchPanen> batches) {
    final line = _editLine;
    if (line == null || batches.isEmpty) return;
    final target = editBatchSyncTarget(
      batches,
      line,
      ref.read(catatPenjualanViewModelProvider).selectedBatch,
    );
    if (target == null || _batchSyncScheduled) return;
    _batchSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _batchSyncScheduled = false;
      if (!mounted) return;
      ref.read(catatPenjualanViewModelProvider.notifier).setBatch(target);
    });
  }

  /// Setelah kuncian lepas, batch pengisi diganti batch asli dengan stok asli.
  /// Bila batch itu tidak ada di daftar, pengguna diminta memilih lagi.
  void _releaseRestoredBatch() {
    if (!_batchRestored || _pendingForThisForm != null) return;
    _batchRestored = false;
    final selectedId = ref
        .read(catatPenjualanViewModelProvider)
        .selectedBatch
        ?.id;
    final real = ref
        .read(batchPanenListProvider)
        .where((batch) => batch.id == selectedId)
        .firstOrNull;
    ref.read(catatPenjualanViewModelProvider.notifier).setBatch(real);
  }

  Future<void> _pickTanggal() async {
    FocusScope.of(context).unfocus();
    final formVm = ref.read(catatPenjualanViewModelProvider.notifier);
    final current = ref.read(catatPenjualanViewModelProvider).tanggal;
    final picked = await pickSaleDate(context, current);
    if (picked != null && mounted) {
      formVm.setTanggal(picked);
      _tanggalController.text = formatTanggalIndo(picked);
    }
  }

  void _showSnack(String message, Color color) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _handleSave() async {
    final permissions =
        ref.read(sessionProvider).user?.permissions ?? const <String>[];
    if (!permissions.contains('penjualan:read') ||
        !permissions.contains('penjualan:write')) {
      return;
    }
    final formVm = ref.read(catatPenjualanViewModelProvider.notifier);

    // Sync data teks sebelum submit
    formVm.setPembeli(_pembeliController.text);
    formVm.setCatatan(_catatanController.text);
    formVm.setHargaPerKgText(_hargaController.text);

    if (_pendingForThisForm == null && isEdit && !widget.itemToEdit!.canEdit) {
      _showSnack(
        'Transaksi ini belum dapat diedit. Muat ulang daftar penjualan.',
        AppColors.dangerRed,
      );
      return;
    }

    final success = await formVm.submitPenjualan(ref, edit: widget.itemToEdit);
    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      _showSnack(
        isEdit
            ? 'Penjualan berhasil diperbarui!'
            : 'Penjualan berhasil dicatat!',
        AppColors.primaryMint,
      );
      Navigator.pop(context, true);
    } else {
      final message =
          ref.read(catatPenjualanViewModelProvider).saveError ??
          formVm.validationMessage() ??
          'Gagal menyimpan penjualan. Coba lagi.';
      _showSnack(message, AppColors.dangerRed);
      _releaseRestoredBatch();
    }
  }

  Future<void> _confirmDiscard() async {
    if (!await confirmSaleDiscard(context) || !mounted) return;
    ref.read(penjualanViewModelProvider.notifier).discardPending();
    _releaseRestoredBatch();
    setState(() {});
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
    final batchList = saleBatchesForForm(
      ref.watch(batchPanenListProvider),
      widget.itemToEdit,
      formState.selectedBatch,
    );
    _scheduleEditBatchSync(batchList);
    // Dibaca ulang tiap kali formulir digambar: kegagalan kirim mengubah formState.
    final pending = _pendingCommand;
    final locked = pending?.target == _saleTarget;
    final otherPending = pending != null && !locked;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.canvasWarm,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pending != null) ...[
                    SaleUncertainNotice(
                      message: locked
                          ? 'Penjualan ini mungkin sudah tersimpan. Isian '
                                'dikunci supaya tidak tercatat dua kali. Kirim '
                                'ulang saat ada sinyal.'
                          : pending.blockedMessage,
                    ),
                    TextButton(
                      onPressed: formState.isLoading ? null : _confirmDiscard,
                      child: const Text('Buang Isian Ini'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  CatatPenjualanFields(
                    formState: formState,
                    formVm: ref.read(catatPenjualanViewModelProvider.notifier),
                    batchList: batchList,
                    itemToEdit: widget.itemToEdit,
                    locked: locked,
                    pembeli: _pembeliController,
                    tanggal: _tanggalController,
                    berat: _beratController,
                    harga: _hargaController,
                    catatan: _catatanController,
                    onPickTanggal: _pickTanggal,
                  ),
                ],
              ),
            ),
          ),

          CatatPenjualanSaveBar(
            label: formState.isLoading
                ? 'Menyimpan...'
                : locked
                ? 'Kirim Ulang Penjualan'
                : (isEdit ? 'Simpan Perubahan' : 'Simpan Penjualan'),
            onTap:
                formState.isLoading ||
                    otherPending ||
                    (!locked && isEdit && !widget.itemToEdit!.canEdit)
                ? null
                : _handleSave,
          ),
        ],
      ),
    );
  }
}
