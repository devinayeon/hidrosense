import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/inventory_record.dart';
import '../../data/models/nursery_record.dart';
import '../../models/seeding_batch_model.dart';
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../components/header.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/row_button.dart';

class SeedingFormPage extends ConsumerStatefulWidget {
  final SowingRecord? sowingRecord;
  final SeedingBatch? seedingItem;

  const SeedingFormPage({super.key, this.sowingRecord, this.seedingItem});

  bool get isEditMode => sowingRecord != null || seedingItem != null;

  @override
  ConsumerState<SeedingFormPage> createState() => _SeedingFormPageState();
}

class _SeedingFormPageState extends ConsumerState<SeedingFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateController;
  late TextEditingController _seedCountController;
  late TextEditingController _noteController;

  String? _selectedInventoryId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.sowingRecord;
    final legacy = widget.seedingItem;
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    _dateController = TextEditingController(
      text: item?.sowingDate ?? legacy?.dateText ?? todayStr,
    );
    _seedCountController = TextEditingController(
      text: (item?.seedCount ?? legacy?.healthyCount ?? 100).toString(),
    );
    _noteController = TextEditingController(
      text: item?.note ?? legacy?.damagedNote ?? '',
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _seedCountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final dateText = _dateController.text.trim();
    final seedCount = int.tryParse(_seedCountController.text.trim()) ?? 0;
    final note = _noteController.text.trim();

    if (dateText.isEmpty || seedCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal dan jumlah benih harus valid!')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.sowingRecord != null) {
        await ref
            .read(connectedNurseryProvider.notifier)
            .updateStatus(widget.sowingRecord!.id, 'aktif');
      } else {
        final inventoryRecords = ref.read(connectedInventoryProvider).records;
        final invId =
            _selectedInventoryId ??
            (inventoryRecords.isNotEmpty ? inventoryRecords.first.id : '1');
        final selectedItem = inventoryRecords
            .where((item) => item.id == invId)
            .firstOrNull;
        final unit = selectedItem?.unit ?? 'btr';
        await ref
            .read(connectedNurseryProvider.notifier)
            .createSowing(
              sowingDate: dateText,
              seedCount: seedCount,
              note: note.isEmpty ? null : note,
              materials: [
                {
                  'id_inventaris': invId,
                  'jumlah': seedCount.toString(),
                  'satuan': unit,
                },
              ],
            );
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan penyemaian: ${serviceError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openSeedPickerSheet(List<InventoryRecord> seedItems) {
    HapticFeedback.lightImpact();
    final currentId =
        _selectedInventoryId ??
        (seedItems.isNotEmpty ? seedItems.first.id : null);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.sm,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pilih Benih dari Inventaris',
                        style: AppTypography.headline.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    itemCount: seedItems.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      indent: AppSpacing.md,
                      color: AppColors.borderSubtle,
                    ),
                    itemBuilder: (_, index) {
                      final item = seedItems[index];
                      final isSelected = item.id == currentId;
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryMint.withValues(alpha: 0.18)
                                : AppColors.secondarySurface,
                            borderRadius: BorderRadius.circular(
                              AppRadius.input,
                            ),
                          ),
                          child: Icon(
                            Icons.eco_rounded,
                            size: 20,
                            color: isSelected
                                ? AppColors.primaryDarkTeal
                                : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: AppTypography.body.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primaryDarkTeal
                                : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Stok: ${item.formattedStock}',
                          style: AppTypography.caption1.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryDarkTeal,
                                size: 22,
                              )
                            : null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedInventoryId = item.id);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEditMode;
    final inventoryState = ref.watch(connectedInventoryProvider);
    final seedItems = inventoryState.records
        .where((i) => i.category.toLowerCase().contains('benih') || i.active)
        .toList();

    return Scaffold(
      appBar: Header(
        titleText: isEdit ? 'Edit Penyemaian' : 'Penyemaian Baru',
        showBackButton: true,
      ),
      backgroundColor: AppColors.canvasWarm,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomInputField(
                label: 'Tanggal Semai (YYYY-MM-DD)',
                hintText: 'YYYY-MM-DD',
                controller: _dateController,
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _dateController.text =
                          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (!isEdit && seedItems.isNotEmpty) ...[
                Text(
                  'PILIH BENIH DARI INVENTARIS',
                  style: AppTypography.caption1.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                InkWell(
                  onTap: () => _openSeedPickerSheet(seedItems),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryMint.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.input,
                            ),
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            size: 18,
                            color: AppColors.primaryDarkTeal,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                seedItems
                                    .firstWhere(
                                      (i) =>
                                          i.id ==
                                          (_selectedInventoryId ??
                                              seedItems.first.id),
                                      orElse: () => seedItems.first,
                                    )
                                    .name,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Tersedia: ${seedItems.firstWhere((i) => i.id == (_selectedInventoryId ?? seedItems.first.id), orElse: () => seedItems.first).formattedStock}',
                                style: AppTypography.caption1.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              CustomInputField(
                label: 'JUMLAH BENIH (BUTIR)',
                hintText: 'Contoh: 500',
                controller: _seedCountController,
                keyboardType: TextInputType.number,
                suffixText: 'Butir',
              ),
              const SizedBox(height: AppSpacing.md),
              CustomInputField(
                label: 'CATATAN PENYEMAIAN',
                hintText: 'Lokasi rak semai atau catatan batch',
                controller: _noteController,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: SafeArea(
          child: RowButton(
            label: _submitting
                ? 'Menyimpan...'
                : (isEdit ? 'Simpan Perubahan' : 'Mulai Semaian & Simpan'),
            backgroundColor: AppColors.primaryDarkTeal,
            textColor: Colors.white,
            height: 52,
            borderRadius: AppRadius.pill,
            onTap: _submitting ? null : _submitForm,
          ),
        ),
      ),
    );
  }
}
