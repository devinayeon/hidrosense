import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/inventory_record.dart';
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../../viewmodels/inventory_draft.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../components/header.dart';
import '../theme/app_theme.dart';
import '../widgets/row_button.dart';

class AddFormInventarisPage extends ConsumerStatefulWidget {
  final InventoryRecord? initialRecord;
  final String? resumeId;
  const AddFormInventarisPage({super.key, this.initialRecord, this.resumeId});

  String? get itemId => initialRecord?.id ?? resumeId;
  bool get isEditMode => itemId != null;

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
  Map<String, String> _errors = {};
  String? _formUserId;
  bool get _locked =>
      _saving || ref.read(connectedInventoryProvider).pendingDraft != null;

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
    final user = ref.read(sessionProvider).user;
    _formUserId = user?.id;
    final pending = user?.permissions.contains('inventaris:write') == true
        ? ref.read(connectedInventoryProvider).pendingDraft
        : null;
    if (pending != null && pending.id == widget.itemId) {
      _nameController.text = pending.name;
      _stockController.text = pending.initialStock;
      _minimumController.text = pending.minimum;
      _selectedCategory = _categoryMap.entries
          .firstWhere((entry) => entry.value == pending.categoryId)
          .key;
      _selectedUnit = pending.unit;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _minimumController.dispose();
    super.dispose();
  }

  Future<void> _saveForm({bool withoutStock = false}) async {
    if (_saving) return;
    final draft = InventoryDraft(
      id: widget.itemId,
      name: _nameController.text.trim(),
      categoryId: _categoryMap[_selectedCategory ?? 'Benih'] ?? '1',
      unit: _selectedUnit ?? 'Pcs',
      minimum: _minimumController.text.trim(),
      initialStock: _stockController.text.trim(),
    );
    setState(() => _errors = draft.errors);
    if (_errors.isNotEmpty) return;
    final user = ref.read(sessionProvider).user;
    if (user == null || !user.permissions.contains('inventaris:write')) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final vm = ref.read(connectedInventoryProvider.notifier);
      final warning = withoutStock
          ? await vm.finishWithoutStock()
          : await vm.saveItem(draft);
      if (!mounted || ref.read(sessionProvider).user != user) return;
      HapticFeedback.mediumImpact();
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            warning == null
                ? (withoutStock
                      ? 'Barang tersimpan tanpa saldo awal.'
                      : 'Barang tersimpan.')
                : 'Barang tersimpan. Gagal memuat data terbaru: $warning',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      // The ViewModel retains the receipt and displays the failed stage inline.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    if (user == null ||
        user.id != _formUserId ||
        !user.permissions.contains('inventaris:write')) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('Anda tidak memiliki akses inventaris.')),
        ),
      );
    }
    final state = ref.watch(connectedInventoryProvider);
    if (state.pendingDraft != null && state.pendingDraft!.id != widget.itemId) {
      return Scaffold(
        appBar: const Header(titleText: 'Inventaris', showBackButton: true),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Penyimpanan barang sebelumnya belum selesai.'),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AddFormInventarisPage(
                        resumeId: state.pendingDraft!.id,
                      ),
                    ),
                  ),
                  child: const Text('Lanjutkan penyimpanan sebelumnya'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: Header(
          titleText: widget.isEditMode ? 'Edit Barang' : 'Tambah Barang',
          titleMaxLines: 2,
          toolbarHeight:
              kToolbarHeight * MediaQuery.textScalerOf(context).scale(1),
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
              borderRadius: AppRadius.pill,
              height: 52.0 * MediaQuery.textScalerOf(context).scale(1),
              onTap: _saving ? null : _saveForm,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.saveError != null || state.pendingDraft != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${state.saveError ?? 'Menyimpan barang…'}${state.pendingDraft != null && !_saving ? '\nIsian dipertahankan. Coba simpan lagi.' : ''}',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              if (state.canFinishWithoutStock)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(44, 48),
                  ),
                  onPressed: _saving
                      ? null
                      : () => _saveForm(withoutStock: true),
                  child: const Text('Selesai tanpa saldo awal'),
                ),
              _label('Nama Barang'),
              const SizedBox(height: AppSpacing.xs),
              _textField(
                _nameController,
                'Contoh: Benih Selada Bataviya',
                error: _errors['name'],
              ),
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
                          error: _errors['stock'],
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
                          onChanged: (val) =>
                              setState(() => _selectedUnit = val),
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
                error: _errors['minimum'],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
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
    String? error,
  }) => Container(
    decoration: BoxDecoration(
      color: readOnly ? AppColors.secondarySurface : AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: TextField(
      controller: controller,
      readOnly: readOnly || _locked,
      keyboardType: keyboardType,
      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        errorText: error,
        errorMaxLines: 4,
        errorStyle: AppTypography.footnote.copyWith(
          color: AppColors.textPrimary,
        ),
        hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
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
  }) => InkWell(
    onTap: _locked
        ? null
        : () => _openPickerSheet<T>(
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
                  : AppTypography.body.copyWith(color: AppColors.textSecondary),
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
                    Flexible(
                      child: Text(
                        title,
                        style: AppTypography.headline.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      color: AppColors.textSecondary,
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
                                    ? AppColors.primaryDarkTeal
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
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryDarkTeal,
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
