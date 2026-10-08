// lib/views/components/form_catat_kerusakan_body.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/baris_tanam_model.dart';
import '../../models/laporan_kerusakan_model.dart';
import '../../models/meja_nft_model.dart';
import '../../viewmodels/baris_tanam_viewmodel.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/item_image_placeholder.dart';
import '../widgets/row_button.dart';

class FormCatatKerusakanBody extends ConsumerStatefulWidget {
  final MejaNft mejaItem;
  final BarisTanam? initialBaris;
  final bool isModal;

  const FormCatatKerusakanBody({
    super.key,
    required this.mejaItem,
    this.initialBaris,
    this.isModal = false,
  });

  /// Static helper untuk menampilkan form dalam Apple HIG Modal Bottom Sheet
  static Future<bool?> show(
    BuildContext context, {
    required MejaNft mejaItem,
    BarisTanam? initialBaris,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FormCatatKerusakanBody(
        mejaItem: mejaItem,
        initialBaris: initialBaris,
        isModal: true,
      ),
    );
  }

  @override
  ConsumerState<FormCatatKerusakanBody> createState() =>
      _FormCatatKerusakanBodyState();
}

class _FormCatatKerusakanBodyState
    extends ConsumerState<FormCatatKerusakanBody> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _mejaController;
  late TextEditingController _barisController;
  late TextEditingController _jumlahRusakController;
  late TextEditingController _kategoriController;
  late TextEditingController _tanggalController;
  late TextEditingController _penyebabController;

  BarisTanam? _selectedBaris;
  DateTime _selectedDate = DateTime.now();
  String? _uploadedPhotoPath;

  final List<String> _kategoriOptions = [
    'Gagal Tumbuh / Busuk Akar',
    'Terserang Hama Ulat / Kutu',
    'Daun Menguning / Layu',
    'Batang Patah / Damaged',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _selectedBaris = widget.initialBaris;

    _mejaController = TextEditingController(text: widget.mejaItem.name);
    _barisController = TextEditingController(
      text: _selectedBaris != null
          ? '${_selectedBaris!.name} (${_selectedBaris!.holesRange})'
          : '',
    );
    _jumlahRusakController = TextEditingController();
    _kategoriController = TextEditingController(
      text: 'Gagal Tumbuh / Busuk Akar',
    );
    _tanggalController = TextEditingController(
      text: _formatDate(_selectedDate),
    );
    _penyebabController = TextEditingController();
  }

  @override
  void dispose() {
    _mejaController.dispose();
    _barisController.dispose();
    _jumlahRusakController.dispose();
    _kategoriController.dispose();
    _tanggalController.dispose();
    _penyebabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final months = [
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
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    return '$day $month ${date.year}';
  }

  void _selectBarisDialog(List<BarisTanam> allBaris) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih Baris / Rentang Lubang',
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
              const SizedBox(height: AppSpacing.sm),
              ...allBaris.map((baris) {
                final isSelected = _selectedBaris?.id == baris.id;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  title: Text(
                    '${baris.name} (${baris.holesRange})',
                    style: AppTypography.body.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryMint,
                        )
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedBaris = baris;
                      _barisController.text =
                          '${baris.name} (${baris.holesRange})';
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _selectKategoriDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih Kategori Kegagalan',
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
              const SizedBox(height: AppSpacing.sm),
              ..._kategoriOptions.map((kat) {
                final isSelected = _kategoriController.text == kat;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  title: Text(
                    kat,
                    style: AppTypography.body.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryMint,
                        )
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _kategoriController.text = kat;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _tanggalController.text = _formatDate(picked);
      });
    }
  }

  void _handleSubmit() {
    if (_selectedBaris == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih baris terlebih dahulu'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      return;
    }

    final jumlahText = _jumlahRusakController.text.trim();
    final int? jumlah = int.tryParse(jumlahText);

    if (jumlah == null || jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan jumlah rusak yang valid'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      return;
    }

    final laporan = LaporanKerusakan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mejaId: widget.mejaItem.id,
      mejaName: widget.mejaItem.name,
      barisId: _selectedBaris!.id,
      barisName: _selectedBaris!.name,
      jumlahRusak: jumlah,
      kategoriKegagalan: _kategoriController.text,
      tanggalDitemukan: _selectedDate,
      penyebabUtama: _penyebabController.text.isNotEmpty
          ? _penyebabController.text
          : null,
      fotoUrl: _uploadedPhotoPath,
    );

    // Update state via Riverpod ViewModel
    ref
        .read(barisTanamViewModelProvider.notifier)
        .submitLaporanKerusakan(laporan);

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Laporan kerusakan berhasil disimpan'),
        backgroundColor: AppColors.primaryMint,
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final allBaris = ref.watch(barisTanamViewModelProvider);

    return Container(
      width: double.infinity,
      height: widget.isModal ? null : double.infinity,
      constraints: widget.isModal
          ? BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            )
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
                    'Catat Kerusakan',
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
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Pilih Meja / Lokasi (Read Only)
                    CustomInputField(
                      label: 'Pilih Meja / Lokasi',
                      hintText: 'Meja NFT #01',
                      controller: _mejaController,
                      readOnly: true,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 2. Pilih Baris / Rentang Lubang
                    CustomInputField(
                      label: 'Pilih Baris / Rentang Lubang',
                      hintText: 'Pilih Baris',
                      controller: _barisController,
                      readOnly: true,
                      suffixIcon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary,
                      ),
                      onTap: () => _selectBarisDialog(allBaris),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 3. Jumlah Rusak (Lubang)
                    CustomInputField(
                      label: 'Jumlah Rusak (Lubang)',
                      hintText: 'Masukkan jumlah bibit rusak (misal: 4)',
                      controller: _jumlahRusakController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 4. Kategori Kegagalan
                    CustomInputField(
                      label: 'Kategori Kegagalan',
                      hintText: 'Pilih Kategori',
                      controller: _kategoriController,
                      readOnly: true,
                      suffixIcon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textTertiary,
                      ),
                      onTap: _selectKategoriDialog,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 5. Tanggal Ditemukan
                    CustomInputField(
                      label: 'Tanggal Ditemukan',
                      hintText: 'Pilih Tanggal',
                      controller: _tanggalController,
                      readOnly: true,
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 6. Penyebab Utama (Estimasi)
                    CustomInputField(
                      label: 'Penyebab Utama (Estimasi)',
                      hintText: 'Sumbatan air nutrisi / Hama ulat',
                      controller: _penyebabController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 7. Bukti Foto (Opsional)
                    Text(
                      'Bukti Foto (Opsional)',
                      style: AppTypography.subheadline.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    GestureDetector(
                      onTap: () {
                        // Action upload foto
                      },
                      child: ItemImagePlaceholder(
                        imageUrl: _uploadedPhotoPath,
                        height: 100,
                        placeholderText: 'UNGGAH FOTO DAUN/AKAR YANG RUSAK',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 8. Tombol Simpan Laporan Kerusakan (Apple HIG 52pt pill button)
                    RowButton(
                      label: 'Simpan Laporan Kerusakan',
                      backgroundColor: AppColors.primaryMint,
                      textColor: Colors.white,
                      borderRadius: AppRadius.pill,
                      height: 52,
                      onTap: _handleSubmit,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
