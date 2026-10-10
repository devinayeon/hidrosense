import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/damage_record.dart';
import '../../data/models/transfer_record.dart';
import '../../viewmodels/damage_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../theme/app_theme.dart';

class FormCatatKerusakanBody extends ConsumerStatefulWidget {
  const FormCatatKerusakanBody({
    super.key,
    required this.tableId,
    required this.tableName,
    this.initialTransfer,
    this.damageRecordToEdit,
  });
  final String tableId, tableName;
  final TransferRecord? initialTransfer;
  final DamageRecord? damageRecordToEdit;

  @override
  ConsumerState<FormCatatKerusakanBody> createState() =>
      _FormCatatKerusakanBodyState();
}

class _FormCatatKerusakanBodyState
    extends ConsumerState<FormCatatKerusakanBody> {
  final _formKey = GlobalKey<FormState>();
  final _count = TextEditingController();
  final _note = TextEditingController();
  late String? _transferId;
  DateTime _date = jakartaToday();
  String _category = 'Gagal Tumbuh / Busuk Akar';
  bool _complete = false;
  static const _categories = [
    'Gagal Tumbuh / Busuk Akar',
    'Terserang Hama Ulat / Kutu',
    'Daun Menguning / Layu',
    'Batang Patah',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.damageRecordToEdit;
    if (edit != null) {
      _transferId = edit.transferId;
      _count.text = edit.plantCount.toString();
      _note.text = edit.note ?? '';
      _date = DateTime.tryParse(edit.date) ?? jakartaToday();
      _category = edit.category;
    } else {
      _transferId = widget.initialTransfer?.id;
    }
    final permissions =
        ref.read(sessionProvider).user?.permissions ?? const <String>[];
    if (permissions.contains('budidaya:read') &&
        permissions.contains('budidaya:write')) {
      final vm = ref.read(damageProvider(widget.tableId).notifier);
      vm.beginDraft();
      final pending = vm.pendingDraft;
      final target = edit == null ? 'create' : 'damage:${edit.id}';
      if (pending != null && vm.pendingTarget == target) {
        _transferId = pending.transferId;
        _count.text = '${pending.plantCount}';
        _note.text = pending.note ?? '';
        _date = DateTime.parse(pending.date);
        _category = pending.category;
      }
    }
  }

  @override
  void dispose() {
    _count.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TransferRecord transfer) async {
    final first = DateTime.parse(transfer.transferDate);
    final last = jakartaToday();
    if (first.isAfter(last)) return;
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: _date.isBefore(first)
          ? first
          : (_date.isAfter(last) ? last : _date),
      builder: (ctx, child) {
        final theme = Theme.of(ctx);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.brightness == Brightness.light
                  ? AppColors.darkNavy
                  : theme.colorScheme.primary,
              onPrimary: theme.brightness == Brightness.light
                  ? AppColors.accentLime
                  : theme.colorScheme.onPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
              ),
            ),
          ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: child!,
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_complete) return;
    final user = ref.read(sessionProvider).user;
    if (user?.permissions.contains('budidaya:write') != true) return;
    final current = ref.read(damageProvider(widget.tableId));
    if (current.submitting || !_formKey.currentState!.validate()) return;
    final notifier = ref.read(damageProvider(widget.tableId).notifier);
    final count = int.parse(_count.text.trim());
    final note = _note.text.trim();

    if (widget.damageRecordToEdit != null) {
      final ok = await notifier.updateDamage(
        widget.damageRecordToEdit!.id,
        date: apiDate(_date),
        plantCount: count,
        category: _category,
        note: note.isNotEmpty ? note : null,
      );
      if (!mounted || !identical(user, ref.read(sessionProvider).user)) return;
      if (ok == DamageSubmitResult.saved ||
          ok == DamageSubmitResult.savedRefreshFailed) {
        _complete = true;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(damageProvider(widget.tableId)).refreshWarning ??
                  'Laporan kerusakan berhasil diperbarui.',
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final err = ref.read(damageProvider(widget.tableId)).error;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Gagal memperbarui laporan kerusakan.'),
          ),
        );
      }
      return;
    }

    final result = await notifier.submit(
      DamageDraft(
        transferId: _transferId!,
        date: apiDate(_date),
        plantCount: count,
        category: _category,
        note: _note.text,
      ),
    );
    if (!mounted || !identical(user, ref.read(sessionProvider).user)) return;
    if (result == DamageSubmitResult.saved ||
        result == DamageSubmitResult.savedRefreshFailed) {
      _complete = true;
      final warning = ref.read(damageProvider(widget.tableId)).refreshWarning;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning ?? 'Laporan kerusakan berhasil disimpan.'),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions =
        ref.watch(sessionProvider).user?.permissions ?? const <String>[];
    if (!permissions.contains('budidaya:read') ||
        !permissions.contains('budidaya:write')) {
      return const Center(
        child: Text('Akses pencatatan kerusakan tidak diizinkan.'),
      );
    }
    final state = ref.watch(damageProvider(widget.tableId));
    final candidates = state.transfers.where((t) => t.id == _transferId);
    final selected = candidates.isEmpty ? null : candidates.first;
    final notifier = ref.read(damageProvider(widget.tableId).notifier);
    final locked = notifier.payloadLocked;
    final categories = {..._categories, _category}.toList();
    final latest = state.reports.values
        .expand((r) => r)
        .where((r) => r.id == widget.damageRecordToEdit?.id);
    final editCount = latest.isEmpty
        ? (widget.damageRecordToEdit?.plantCount ?? 0)
        : latest.first.plantCount;
    final enteredCount = int.tryParse(_count.text.trim());
    final canReplay =
        state.uncertainDraft != null &&
        enteredCount != null &&
        _transferId != null &&
        jsonEncode(state.uncertainDraft!.toJson()) ==
            jsonEncode(
              DamageDraft(
                transferId: _transferId!,
                date: apiDate(_date),
                plantCount: enteredCount,
                category: _category,
                note: _note.text,
              ).toJson(),
            );
    return PopScope(
      canPop: !state.submitting,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.tableName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (state.loading) const LinearProgressIndicator(),
              if (state.uncertainDraft != null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Hasil penyimpanan belum dapat dipastikan. Coba simpan lagi dengan isian yang sama.',
                  ),
                ),
              if (state.error != null) ...[
                Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: state.submitting
                      ? null
                      : () => ref
                            .read(damageProvider(widget.tableId).notifier)
                            .refresh(),
                  child: const Text('Muat ulang batch'),
                ),
              ],
              if (!state.loading && state.transfers.isEmpty)
                const Text('Belum ada batch pemindahan pada meja ini.'),
              DropdownButtonFormField<String>(
                key: ValueKey(selected?.id),
                initialValue: selected?.id,
                isExpanded: true,
                itemHeight: null,
                selectedItemBuilder: (_) =>
                    state.transfers.map((t) => Text('Batch #${t.id}')).toList(),
                decoration: const InputDecoration(
                  labelText: 'Batch pemindahan',
                ),
                items: state.transfers
                    .map(
                      (t) =>
                          DropdownMenuItem(value: t.id, child: Text(t.label)),
                    )
                    .toList(),
                onChanged:
                    state.submitting ||
                        locked ||
                        widget.damageRecordToEdit != null
                    ? null
                    : (id) => setState(() => _transferId = id),
                validator: (_) =>
                    selected == null ? 'Pilih batch pemindahan.' : null,
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Dipindahkan ${selected.transferDate}. ${selected.activePlants} tanaman aktif dari ${selected.plantCount} tanaman dipindahkan.',
                  ),
                ),
              const SizedBox(height: 16),
              const Text('Jumlah tanaman rusak'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _count,
                onChanged: (_) => setState(() {}),
                enabled: !state.submitting && !locked,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(errorMaxLines: 4),
                validator: (value) {
                  final count = int.tryParse(value?.trim() ?? '');
                  final maxAllowed = selected == null
                      ? 0
                      : selected.activePlants + editCount;
                  return count == null ||
                          count <= 0 ||
                          selected == null ||
                          (!canReplay && count > maxAllowed)
                      ? 'Jumlah harus 1 sampai $maxAllowed tanaman.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                itemHeight: null,
                selectedItemBuilder: (_) =>
                    categories.map((c) => Text(c.split(' / ').first)).toList(),
                decoration: const InputDecoration(labelText: 'Jenis kerusakan'),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: state.submitting || locked
                    ? null
                    : (value) => setState(() => _category = value!),
              ),
              if (_category.contains(' / '))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_category),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 48),
                ),
                onPressed: state.submitting || locked || selected == null
                    ? null
                    : () => _pickDate(selected),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Tanggal kejadian: ${apiDate(_date)}'),
              ),
              const SizedBox(height: 16),
              const Text('Keterangan (opsional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _note,
                onChanged: (_) => setState(() {}),
                enabled: !state.submitting && !locked,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 52),
                  backgroundColor: AppColors.darkNavy,
                  foregroundColor: AppColors.accentLime,
                ),
                onPressed:
                    state.submitting ||
                        state.loading ||
                        selected == null ||
                        (selected.activePlants == 0 &&
                            widget.damageRecordToEdit == null &&
                            !canReplay)
                    ? null
                    : _submit,
                child: Text(
                  state.submitting
                      ? 'Menyimpan laporan...'
                      : (widget.damageRecordToEdit != null
                            ? 'Simpan Perubahan Laporan'
                            : 'Simpan Laporan Kerusakan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
