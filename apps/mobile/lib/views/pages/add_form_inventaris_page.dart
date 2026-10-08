import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/inventory_record.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../components/header.dart';
import '../theme/app_theme.dart';
import '../widgets/row_button.dart';

class AddFormInventarisPage extends ConsumerStatefulWidget {
  final InventoryRecord? initialRecord;
  const AddFormInventarisPage({super.key, this.initialRecord});

  bool get isEditMode => initialRecord != null;

  @override
  ConsumerState<AddFormInventarisPage> createState() =>
      _AddFormInventarisPageState();
}

class _AddFormInventarisPageState extends ConsumerState<AddFormInventarisPage> {
  late TextEditingController _nameController;
  late TextEditingController _stockController;
  late TextEditingController _minimumController;

  String? _selectedCategory;
  String? _selectedUnit;
  bool _saving = false;

  final Map<String, String> _categoryMap = {
    'Benih': '1',
    'Pupuk': '2',
    'Obat': '3',
    'Peralatan': '4',
    'Media Tanam': '5',
  };

  final List<String> _units = [
    'Kg',
    'Gram',
    'Liter',
    'Ml',
    'btr',
    'Pcs',
    'Blok',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initialRecord;
    _nameController = TextEditingController(text: item?.name ?? '');
    _stockController = TextEditingController(text: item?.balance ?? '');
    _minimumController = TextEditingController(text: item?.minimum ?? '');

    if (item?.category != null && _categoryMap.containsKey(item!.category)) {
      _selectedCategory = item.category;
    }
    if (item?.unit != null) {
      final match = _units.firstWhere(
        (u) => u.toLowerCase() == item!.unit.toLowerCase(),
        orElse: () => item!.unit,
      );
      if (!_units.contains(match)) _units.add(match);
      _selectedUnit = match;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _minimumController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama barang tidak boleh kosong')),
      );
      return;
    }

    final categoryId = _categoryMap[_selectedCategory ?? 'Benih'] ?? '1';
    final unit = _selectedUnit ?? 'Pcs';
    final minimum = _minimumController.text.trim();
    final initialStock = _stockController.text.trim();

    setState(() => _saving = true);
    try {
      final user = ref.read(sessionProvider).user;
      if (user == null) throw StateError('Sesi tidak aktif');
      final repo = InventoryRepository(
        ref.read(apiClientProvider),
        ref.read(inventoryCacheProvider),
        userId: user.id,
      );

      if (widget.isEditMode) {
        await repo.updateItem(
          widget.initialRecord!.id,
          name: name,
          categoryId: categoryId,
          unit: unit,
          minimum: minimum,
        );
      } else {
        final created = await repo.createItem(
          name: name,
          categoryId: categoryId,
          unit: unit,
          minimum: minimum,
        );
        final stockVal = double.tryParse(initialStock) ?? 0;
        if (stockVal > 0) {
          await repo.recordStockMovement(
            direction: 'masuk',
            details: [
              {
                'id_inventaris': created.id,
                'jumlah': initialStock,
                'satuan': unit,
              },
            ],
            note: 'Saldo awal registrasi barang',
          );
        }
      }

      await ref.read(connectedInventoryProvider.notifier).refresh();
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: ${serviceError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        titleText: widget.isEditMode ? 'Edit Barang' : 'Tambah Barang Baru',
        showBackButton: true,
      ),
      backgroundColor: AppColors.canvasWarm,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.canvasWarm,
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: RowButton(
            label: _saving
                ? 'Menyimpan...'
                : (widget.isEditMode ? 'Simpan Perubahan' : 'Simpan Barang'),
            backgroundColor: AppColors.primaryMint,
            textColor: Colors.white,
            borderRadius: AppRadius.pill,
            height: 52.0,
            onTap: _saving ? null : _saveForm,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Nama Barang'),
            const SizedBox(height: AppSpacing.xs),
            _textField(_nameController, 'Contoh: Benih Selada Bataviya'),
            const SizedBox(height: AppSpacing.md),
            _label('Kategori'),
            const SizedBox(height: AppSpacing.xs),
            _selectorField<String>(
              value: _selectedCategory,
              hintText: 'Pilih Kategori Barang',
              modalTitle: 'Pilih Kategori Barang',
              items: _categoryMap.keys.toList(),
              iconBuilder: (cat) {
                final c = cat.toLowerCase();
                if (c.contains('benih')) return Icons.eco_rounded;
                if (c.contains('pupuk') || c.contains('nutrisi')) {
                  return Icons.water_drop_rounded;
                }
                if (c.contains('obat')) return Icons.shield_rounded;
                if (c.contains('peralatan')) return Icons.handyman_rounded;
                return Icons.grid_view_rounded;
              },
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Stok Awal'),
                      const SizedBox(height: AppSpacing.xs),
                      _textField(
                        _stockController,
                        '0',
                        keyboardType: TextInputType.number,
                        readOnly: widget.isEditMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Satuan'),
                      const SizedBox(height: AppSpacing.xs),
                      _selectorField<String>(
                        value: _selectedUnit,
                        hintText: 'Satuan',
                        modalTitle: 'Pilih Satuan Barang',
                        items: _units,
                        onChanged: (val) => setState(() => _selectedUnit = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _label('Stok Minimum (Peringatan)'),
            const SizedBox(height: AppSpacing.xs),
            _textField(
              _minimumController,
              'Contoh: 5 (Opsional)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: AppTypography.subheadline.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) => Container(
    decoration: BoxDecoration(
      color: readOnly ? AppColors.secondarySurface : AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: InputBorder.none,
      ),
    ),
  );

  Widget _selectorField<T>({
    required T? value,
    required String hintText,
    required String modalTitle,
    required List<T> items,
    required ValueChanged<T> onChanged,
    IconData Function(T)? iconBuilder,
  }) => GestureDetector(
    onTap: () => _openPickerSheet<T>(
      title: modalTitle,
      items: items,
      selectedValue: value,
      onChanged: onChanged,
      iconBuilder: iconBuilder,
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              value != null ? value.toString() : hintText,
              style: value != null
                  ? AppTypography.body.copyWith(color: AppColors.textPrimary)
                  : AppTypography.body.copyWith(color: AppColors.textTertiary),
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
  );

  void _openPickerSheet<T>({
    required String title,
    required List<T> items,
    required T? selectedValue,
    required ValueChanged<T> onChanged,
    IconData Function(T)? iconBuilder,
  }) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal),
            ),
          ),
          padding: EdgeInsets.only(
            top: AppSpacing.xs,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: AppTypography.headline.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderSubtle),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: AppColors.borderSubtle),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final isSelected = item == selectedValue;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onChanged(item);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        color: isSelected
                            ? AppColors.accentMintSoft.withValues(alpha: 0.5)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            if (iconBuilder != null) ...[
                              Icon(
                                iconBuilder(item),
                                size: 20,
                                color: isSelected
                                    ? AppColors.primaryMint
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              child: Text(
                                item.toString(),
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
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
