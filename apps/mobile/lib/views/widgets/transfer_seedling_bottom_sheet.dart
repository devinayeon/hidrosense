import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/nursery_record.dart';
import '../../data/models/table_record.dart';
import '../../models/seeding_batch_model.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../theme/app_theme.dart';
import 'custom_input_field.dart';
import 'fluid_capacity_meter.dart';
import 'row_button.dart';
import 'row_info_card_md.dart';

/// Modal Bottom Sheet B009: Pemindahan Bibit Semai ke Meja NFT
/// dengan validasi sisa lubang meja tanam dan estimasi panen standar 45 hari.
class TransferSeedlingBottomSheet extends ConsumerStatefulWidget {
  final SowingRecord? sowingRecord;
  final SeedingBatch? seedingItem;
  final VoidCallback? onSuccess;

  const TransferSeedlingBottomSheet({
    super.key,
    this.sowingRecord,
    this.seedingItem,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    SowingRecord? sowingRecord,
    SeedingBatch? seedingItem,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransferSeedlingBottomSheet(
        sowingRecord: sowingRecord,
        seedingItem: seedingItem,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  ConsumerState<TransferSeedlingBottomSheet> createState() =>
      _TransferSeedlingBottomSheetState();
}

class _TransferSeedlingBottomSheetState
    extends ConsumerState<TransferSeedlingBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _countController;
  TableRecord? _selectedTable;
  String? _errorValidation;

  @override
  void initState() {
    super.initState();
    final defaultCount = widget.sowingRecord?.seedCount ??
        ((widget.seedingItem != null && widget.seedingItem!.healthyCount > 0)
            ? widget.seedingItem!.healthyCount
            : widget.seedingItem?.seedCount) ??
        50;
    _countController = TextEditingController(text: defaultCount.toString());
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableState = ref.watch(connectedTableProvider);
    final availableTables =
        tableState.records.where((t) => !t.isMaintenance).toList();

    // Default table selection jika belum dipilih
    if (_selectedTable == null && availableTables.isNotEmpty) {
      _selectedTable = availableTables.first;
    }

    final batchName = widget.sowingRecord?.batchName ??
        (widget.seedingItem != null
            ? 'Batch #${widget.seedingItem!.batchNumber} (${widget.seedingItem!.variety})'
            : 'Semaian Siap Pindah');

    final maxSeedlings = widget.sowingRecord?.seedCount ??
        ((widget.seedingItem != null && widget.seedingItem!.healthyCount > 0)
            ? widget.seedingItem!.healthyCount
            : widget.seedingItem?.seedCount) ??
        100;

    // Kalkulasi estimasi panen baku 45 hari (B009 Decision)
    final transferDate = DateTime.now();
    final estimatedHarvestDate = transferDate.add(const Duration(days: 45));
    final harvestFormatted =
        DateFormat('dd MMMM yyyy').format(estimatedHarvestDate);

    final int availableHoles = _selectedTable != null
        ? (_selectedTable!.holeCount - _selectedTable!.activePlants).clamp(0, 9999)
        : 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvasWarm,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.modal),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grabber Handle Apple HIG
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

              // Header Modal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Pindahkan Bibit ke Meja NFT',
                      style: AppTypography.title3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Kartu Ringkasan Batch
              RowInfoCardMd(
                backgroundColor: Colors.white,
                borderColor: AppColors.borderLight,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batchName,
                      style: AppTypography.headline.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tersedia: $maxSeedlings bibit semai berumur ≥15 HSS',
                      style: AppTypography.subheadline.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Pilihan Meja NFT Tujuan
              Text(
                'PILIH MEJA TANAM TUJUAN',
                style: AppTypography.caption1.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (availableTables.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.warningOrange),
                  ),
                  child: Text(
                    'Tidak ada meja tanam aktif yang tersedia. Pastikan ada meja NFT dalam status aktif.',
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.darkNavy,
                    ),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TableRecord>(
                      value: _selectedTable,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                      items: availableTables.map((table) {
                        final remaining = table.holeCount - table.activePlants;
                        return DropdownMenuItem<TableRecord>(
                          value: table,
                          child: Text(
                            '${table.displayName} (Sisa $remaining / ${table.holeCount} Lubang)',
                            style: AppTypography.body,
                          ),
                        );
                      }).toList(),
                      onChanged: (selected) {
                        setState(() {
                          _selectedTable = selected;
                          _errorValidation = null;
                        });
                      },
                    ),
                  ),
                ),
                if (_selectedTable != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  RowInfoCardMd(
                    backgroundColor: Colors.white,
                    borderColor: AppColors.borderSubtle,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: FluidCapacityMeter(
                      activePlants: _selectedTable!.activePlants,
                      totalCapacity: _selectedTable!.holeCount,
                      height: 10,
                      showLabel: true,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.md),

              // Input Jumlah Bibit yang Dipindahkan
              CustomInputField(
                label: 'JUMLAH BIBIT YANG DIPINDAHKAN',
                hintText: 'Masukkan jumlah bibit (maks. $availableHoles)',
                controller: _countController,
                keyboardType: TextInputType.number,
                errorText: _errorValidation,
                suffixText: 'Bibit',
              ),
              const SizedBox(height: AppSpacing.md),

              // Estimasi Panen Standar 45 Hari (B009)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.primaryMint.withOpacity(0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      color: AppColors.primaryDarkTeal,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimasi Waktu Panen (45 Hari)',
                            style: AppTypography.headline.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDarkTeal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Panen diprediksi pada: $harvestFormatted',
                            style: AppTypography.body.copyWith(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Tombol Konfirmasi Aksi
              RowButton(
                label: 'Konfirmasi Pemindahan ke Meja',
                backgroundColor: AppColors.darkNavy,
                textColor: AppColors.accentLime,
                onTap: () {
                  final text = _countController.text.trim();
                  final count = int.tryParse(text);

                  if (count == null || count <= 0) {
                    setState(() {
                      _errorValidation = 'Jumlah bibit harus berupa angka lebih dari 0';
                    });
                    HapticFeedback.heavyImpact();
                    return;
                  }

                  if (count > maxSeedlings) {
                    setState(() {
                      _errorValidation =
                          'Jumlah bibit melebihi stok semaian ($maxSeedlings bibit)';
                    });
                    HapticFeedback.heavyImpact();
                    return;
                  }

                  if (_selectedTable != null && count > availableHoles) {
                    setState(() {
                      _errorValidation =
                          'Meja tanam hanya memiliki sisa $availableHoles lubang kosong';
                    });
                    HapticFeedback.heavyImpact();
                    return;
                  }

                  // Berhasil divalidasi
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Berhasil memindahkan $count bibit ke ${_selectedTable?.displayName ?? "Meja NFT"}. Estimasi panen: $harvestFormatted',
                      ),
                      backgroundColor: AppColors.primaryDarkTeal,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                    ),
                  );

                  widget.onSuccess?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
