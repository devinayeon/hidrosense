import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/business_date.dart';
import '../../data/models/inventory_record.dart';
import '../../data/models/nursery_record.dart';
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../../viewmodels/sowing_draft.dart';
import '../components/header.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/row_button.dart';

class SeedingFormPage extends ConsumerStatefulWidget {
  const SeedingFormPage({super.key, this.sowingRecord, this.resumeId});
  final SowingRecord? sowingRecord;
  final String? resumeId;
  String? get itemId => sowingRecord?.id ?? resumeId;
  bool get isEditMode => itemId != null;
  @override
  ConsumerState<SeedingFormPage> createState() => _SeedingFormPageState();
}

class _SeedingFormPageState extends ConsumerState<SeedingFormPage> {
  late final TextEditingController _date, _count, _note, _amount;
  String? _inventoryId, _userId;
  bool _submitting = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).user;
    _userId = user?.id;
    final pending = user?.permissions.contains('penyemaian:write') == true
        ? ref.read(connectedNurseryProvider).pendingDraft
        : null;
    final draft = pending?.id == widget.itemId ? pending : null;
    final item = widget.sowingRecord;
    _date = TextEditingController(
      text: draft?.date ?? item?.sowingDate ?? apiDate(jakartaToday()),
    );
    _count = TextEditingController(
      text: (draft?.seedCount ?? item?.seedCount ?? 100).toString(),
    );
    _note = TextEditingController(text: draft?.note ?? item?.note ?? '');
    _amount = TextEditingController(text: draft?.amount ?? '');
    _inventoryId = draft?.inventoryId;
  }

  @override
  void dispose() {
    for (final controller in [_date, _count, _note, _amount]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _locked =>
      _submitting || ref.read(connectedNurseryProvider).pendingDraft != null;

  Future<void> _submit() async {
    if (_submitting || ref.read(connectedNurseryProvider).saving) return;
    final user = ref.read(sessionProvider).user;
    if (user == null ||
        user.id != _userId ||
        !user.permissions.contains('penyemaian:write')) {
      return;
    }
    final seeds = widget.isEditMode
        ? const <InventoryRecord>[]
        : _seeds(ref.read(connectedInventoryProvider).records);
    final selected = seeds.where((item) => item.id == _inventoryId).firstOrNull;
    final pending = ref.read(connectedNurseryProvider).pendingDraft;
    final count = int.tryParse(_count.text.trim()) ?? 0;
    final unit = selected?.unit ?? '';
    final isCountUnit = [
      'btr',
      'butir',
      'pcs',
      'biji',
    ].contains(unit.toLowerCase());
    final draft =
        pending ??
        SowingDraft(
          id: widget.itemId,
          date: _date.text.trim(),
          seedCount: count,
          note: _note.text.trim(),
          inventoryId: selected?.id,
          amount: _amount.text.trim().isEmpty && isCountUnit
              ? '$count'
              : _amount.text.trim(),
          unit: unit,
        );
    setState(() => _errors = draft.errors);
    if (_errors.isNotEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      final warning = await ref
          .read(connectedNurseryProvider.notifier)
          .saveSowing(draft);
      if (!mounted || ref.read(sessionProvider).user != user) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            warning == null
                ? 'Penyemaian tersimpan.'
                : 'Penyemaian tersimpan. Data terbaru belum dimuat: $warning',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      // The ViewModel keeps an uncertain command for exact replay.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<InventoryRecord> _seeds(List<InventoryRecord> records) => records
      .where(
        (item) => item.active && item.category.toLowerCase().contains('benih'),
      )
      .toList();

  Future<void> _chooseDate() async {
    if (_locked || widget.isEditMode) return;
    final today = jakartaToday();
    final current = DateTime.tryParse(_date.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isAfter(today) ? current : today,
      firstDate: DateTime(1),
      lastDate: today,
    );
    if (!mounted || _locked) return;
    if (picked != null) setState(() => _date.text = apiDate(picked));
  }

  Future<void> _chooseSeed(List<InventoryRecord> seeds) async {
    if (_locked) return;
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.modal),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pilih Benih dari Inventaris',
                        style: AppTypography.headline,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: seeds
                      .map(
                        (item) => ListTile(
                          title: Text(item.name, style: AppTypography.body),
                          subtitle: Text(
                            'Stok: ${item.formattedStock}',
                            style: AppTypography.caption1.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: item.id == _inventoryId
                              ? const Icon(
                                  Icons.check,
                                  color: AppColors.textPrimary,
                                )
                              : null,
                          onTap: () => Navigator.pop(ctx, item.id),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && !_locked && id != null) {
      setState(() {
        _inventoryId = id;
        _amount.clear();
      });
    }
  }

  Widget _error(String message) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(message, style: AppTypography.footnote),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    if (user == null ||
        user.id != _userId ||
        !user.permissions.contains('penyemaian:write')) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('Anda tidak memiliki akses penyemaian.')),
        ),
      );
    }
    final state = ref.watch(connectedNurseryProvider);
    if (state.pendingDraft != null && state.pendingDraft!.id != widget.itemId) {
      return Scaffold(
        appBar: const Header(titleText: 'Penyemaian', showBackButton: true),
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    SeedingFormPage(resumeId: state.pendingDraft!.id),
              ),
            ),
            child: const Text('Lanjutkan penyimpanan batch sebelumnya'),
          ),
        ),
      );
    }
    if (widget.sowingRecord?.status == 'selesai') {
      return const Scaffold(
        appBar: Header(titleText: 'Penyemaian selesai', showBackButton: true),
        body: Center(
          child: Text('Penyemaian yang selesai tidak dapat diubah.'),
        ),
      );
    }
    final inventory = widget.isEditMode
        ? null
        : ref.watch(connectedInventoryProvider);
    final seeds = _seeds(inventory?.records ?? []);
    final selected = seeds.where((item) => item.id == _inventoryId).firstOrNull;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: Header(
          titleText: widget.isEditMode ? 'Edit Penyemaian' : 'Penyemaian Baru',
          showBackButton: true,
          toolbarHeight: kToolbarHeight * scale,
          titleMaxLines: 2,
        ),
        backgroundColor: AppColors.canvasWarm,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.saveError != null) _error(state.saveError!),
              if (state.pendingDraft != null && !_submitting)
                _error(
                  'Hasil belum pasti. Isian dipertahankan saat mencoba lagi.',
                ),
              CustomInputField(
                label: 'Tanggal Semai',
                hintText: 'YYYY-MM-DD',
                controller: _date,
                readOnly: true,
                onTap: widget.isEditMode || _locked ? null : _chooseDate,
                errorText: _errors['date'],
                errorColor: AppColors.textPrimary,
              ),
              if (widget.isEditMode)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Tanggal semai dan pemakaian stok tetap sesuai pencatatan awal.',
                    style: AppTypography.footnote,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              if (!widget.isEditMode) ...[
                if (inventory!.loading) const LinearProgressIndicator(),
                if (inventory.error != null) ...[
                  _error(inventory.error!),
                  TextButton(
                    onPressed: _locked
                        ? null
                        : ref.read(connectedInventoryProvider.notifier).refresh,
                    child: const Text('Muat ulang inventaris'),
                  ),
                ],
                if (!inventory.loading && seeds.isEmpty)
                  _error('Belum ada benih aktif di inventaris.'),
                OutlinedButton(
                  onPressed: _locked || seeds.isEmpty
                      ? null
                      : () => _chooseSeed(seeds),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(44, 48),
                  ),
                  child: Text(selected?.name ?? 'Pilih Benih dari Inventaris'),
                ),
                if (_errors['seed'] case final String error) _error(error),
                if (selected != null)
                  Text(
                    'Tersedia: ${selected.formattedStock}',
                    style: AppTypography.footnote,
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
              CustomInputField(
                label: 'Jumlah Benih (Butir)',
                hintText: 'Contoh: 100',
                controller: _count,
                readOnly: _locked,
                keyboardType: TextInputType.number,
                errorText: _errors['count'],
                errorColor: AppColors.textPrimary,
              ),
              const SizedBox(height: AppSpacing.md),
              if (!widget.isEditMode) ...[
                CustomInputField(
                  label:
                      'Pemakaian Stok${selected == null ? '' : ' (${selected.unit})'}',
                  hintText: 'Jumlah sesuai satuan inventaris',
                  controller: _amount,
                  readOnly: _locked,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  errorText: _errors['amount'],
                  errorColor: AppColors.textPrimary,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Untuk satuan butir/Pcs, kosongkan agar mengikuti jumlah benih. Untuk gram/kg, isi jumlah yang dipakai.',
                    style: AppTypography.footnote,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              CustomInputField(
                label: 'Catatan Penyemaian',
                hintText: 'Lokasi rak atau catatan batch',
                controller: _note,
                readOnly: _locked,
                maxLines: 3,
                errorText: _errors['note'],
                errorColor: AppColors.textPrimary,
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: RowButton(
              label: _submitting ? 'Menyimpan...' : 'Simpan Penyemaian',
              height: 52 * scale,
              borderRadius: AppRadius.pill,
              onTap: _submitting ? null : _submit,
            ),
          ),
        ),
      ),
    );
  }
}
