import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/table_record.dart';
import '../../models/meja_nft_model.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/row_button.dart';

class FormMejaNftBody extends ConsumerStatefulWidget {
  final TableRecord? tableRecord;
  final MejaNft? mejaItem;

  const FormMejaNftBody({super.key, this.tableRecord, this.mejaItem});

  @override
  ConsumerState<FormMejaNftBody> createState() => _FormMejaNftBodyState();
}

class _FormMejaNftBodyState extends ConsumerState<FormMejaNftBody> {
  late TextEditingController _codeController;
  late TextEditingController _capacityController;
  late TextEditingController _notesController;
  String _selectedStatus = 'tersedia';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final rec = widget.tableRecord;
    final item = widget.mejaItem;
    _codeController = TextEditingController(
      text: rec?.code ?? item?.name ?? '',
    );
    _capacityController = TextEditingController(
      text: (rec?.holeCount ?? item?.capacityTotal ?? 250).toString(),
    );
    _notesController = TextEditingController(
      text: rec?.notes ?? item?.notes ?? '',
    );
    _selectedStatus =
        rec?.status ??
        (item?.status == MejaStatus.perawatan ? 'pemeliharaan' : 'tersedia');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _capacityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    final code = _codeController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 0;
    final notes = _notesController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode / Nama Meja tidak boleh kosong')),
      );
      return;
    }
    if (capacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kapasitas lubang harus lebih dari 0')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final rec = widget.tableRecord;
      if (rec == null) {
        await ref
            .read(connectedTableProvider.notifier)
            .createTable(
              code: code,
              holeCount: capacity,
              status: _selectedStatus,
              notes: notes.isNotEmpty ? notes : null,
            );
      } else {
        await ref
            .read(connectedTableProvider.notifier)
            .updateTable(
              rec.id,
              code: code,
              holeCount: capacity,
              status: _selectedStatus,
              notes: notes.isNotEmpty ? notes : null,
            );
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rec == null
                  ? 'Meja tanam berhasil ditambahkan'
                  : 'Meja tanam berhasil diperbarui',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan meja: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.canvasWarm,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomInputField(
              label: 'Kode / Nama Meja',
              hintText: 'Contoh: M-01 atau Meja NFT #01',
              controller: _codeController,
            ),
            const SizedBox(height: AppSpacing.md),
            CustomInputField(
              label: 'Kapasitas Lubang Default',
              hintText: '250',
              controller: _capacityController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Status Meja Utama',
              style: AppTypography.subheadline.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                final options = [
                  ('tersedia', 'Tersedia / Aktif', Icons.check_circle_outline),
                  ('pemeliharaan', 'Perawatan', Icons.build_circle_outlined),
                  ('penuh', 'Penuh', Icons.grid_goldenratio),
                  ('nonaktif', 'Nonaktif', Icons.block_outlined),
                ];
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Container(
                    decoration: const BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.modal),
                      ),
                    ),
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xs,
                      bottom: AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 5,
                          margin: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.borderLight,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            'Pilih Status Meja',
                            style: AppTypography.headline.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.borderSubtle),
                        ...options.map((opt) {
                          final isSelected = _selectedStatus == opt.$1;
                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedStatus = opt.$1);
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 14,
                              ),
                              color: isSelected
                                  ? AppColors.accentMintSoft.withValues(
                                      alpha: 0.5,
                                    )
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  Icon(
                                    opt.$3,
                                    size: 20,
                                    color: isSelected
                                        ? AppColors.primaryMint
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      opt.$2,
                                      style: AppTypography.body.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.primaryDarkTeal
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.primaryMint,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: AppColors.borderLight, width: 1.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedStatus == 'tersedia'
                          ? 'Tersedia / Aktif'
                          : _selectedStatus == 'pemeliharaan'
                          ? 'Perawatan'
                          : _selectedStatus == 'penuh'
                          ? 'Penuh'
                          : 'Nonaktif',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CustomInputField(
              label: 'Catatan / Spesifikasi',
              hintText: 'Merek pompa, debit air, tipe pipa PVC',
              controller: _notesController,
            ),
            const SizedBox(height: AppSpacing.xl),
            RowButton(
              label: _submitting
                  ? 'Menyimpan...'
                  : widget.tableRecord == null
                  ? 'Simpan Meja'
                  : 'Perbarui Pengaturan Meja',
              backgroundColor: AppColors.darkNavy,
              textColor: AppColors.accentLime,
              borderRadius: AppRadius.pill,
              height: 52,
              onTap: _submitting ? null : _saveForm,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
