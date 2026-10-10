import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/business_date.dart';
import '../../core/uuid.dart';
import '../../data/models/nursery_record.dart';
import '../../data/models/table_record.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../theme/app_theme.dart';

class SeedlingTransferSheet extends ConsumerStatefulWidget {
  const SeedlingTransferSheet({
    super.key,
    required this.sowingRecord,
    required this.onTransferred,
  });

  final SowingRecord sowingRecord;
  final VoidCallback onTransferred;

  @override
  ConsumerState<SeedlingTransferSheet> createState() =>
      _SeedlingTransferSheetState();
}

class _SeedlingTransferSheetState extends ConsumerState<SeedlingTransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  String? _tableId;
  String? _error;
  String? _refreshError;
  bool _refreshing = false;
  bool _acknowledgedSave = false;
  late final Map<(String, String, String), SeedlingTransferCommand> _commands;
  (String, String, String)? _scope;
  SeedlingTransferCommand? _command;

  bool get _submitting => _command?.submitting ?? false;
  bool get _saved => _command?.saved ?? false;
  SeedlingTransferPayload? get _pendingTransfer => _command?.payload;
  DateTime get _today => jakartaToday(ref.read(nurseryClockProvider)());
  bool get _matchesCurrentScope {
    final user = ref.read(sessionProvider).user;
    return user != null &&
        _scope ==
            (
              ref.read(apiClientProvider).serverOrigin,
              user.id,
              widget.sowingRecord.id,
            );
  }

  DateTime? get _firstDate {
    final sowingDate = DateTime.tryParse(widget.sowingRecord.sowingDate);
    return sowingDate == null
        ? null
        : DateUtils.dateOnly(sowingDate).add(const Duration(days: 15));
  }

  @override
  void initState() {
    super.initState();
    _date = _today;
    _commands = ref.read(seedlingTransferCommandsProvider);
    final user = ref.read(sessionProvider).user;
    if (user != null) {
      _scope = (
        ref.read(apiClientProvider).serverOrigin,
        user.id,
        widget.sowingRecord.id,
      );
      _command = _commands[_scope];
      if (_command != null) {
        _restoreCommand(_command!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_acknowledgeSave());
        });
      }
    }
  }

  void _restoreCommand(SeedlingTransferCommand command) {
    _command?.removeListener(_commandChanged);
    _command = command;
    final pending = command.payload;
    _tableId = pending.tableId;
    _date = DateTime.parse(pending.transferDate);
    _quantity.text = '${pending.plantCount}';
    _note.text = pending.note;
    command.addListener(_commandChanged);
  }

  void _commandChanged() {
    final command = _command;
    if (command != null && command.rejected) {
      _error = command.error;
      command.removeListener(_commandChanged);
      _command = null;
    }
    if (mounted) {
      setState(() {});
      unawaited(_acknowledgeSave());
    }
  }

  Future<void> _acknowledgeSave() async {
    if (!mounted || !_saved || _acknowledgedSave || !_matchesCurrentScope) {
      return;
    }
    _acknowledgedSave = true;
    widget.onTransferred();
    if (mounted) await _refreshData();
    if (mounted &&
        _matchesCurrentScope &&
        identical(_commands[_scope], _command)) {
      _commands.remove(_scope);
    }
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  void dispose() {
    _command?.removeListener(_commandChanged);
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final firstDate = _firstDate;
    final today = _today;
    if (firstDate == null || firstDate.isAfter(today)) return;
    final initialDate = _date.isBefore(firstDate)
        ? firstDate
        : _date.isAfter(today)
        ? today
        : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today,
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
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _refreshData() async {
    if (_refreshing || !_matchesCurrentScope) return;
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      await Future.wait([
        ref.read(connectedNurseryProvider.notifier).refreshAfterTransfer(),
        ref.read(connectedTableProvider.notifier).refresh(),
      ]);
      if (!mounted) return;
      final nurseryError = ref.read(connectedNurseryProvider).error;
      final tableError = ref.read(connectedTableProvider).error;
      if (nurseryError != null || tableError != null) {
        _refreshError = 'Data belum diperbarui. ${nurseryError ?? tableError}';
      }
    } catch (error) {
      if (mounted) {
        _refreshError = 'Data belum diperbarui. ${serviceError(error)}';
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _submit(TableRecord? table) async {
    if (_submitting || _saved) return;
    final user = ref.read(sessionProvider).user;
    if (user == null ||
        !user.permissions.contains('penyemaian:write') ||
        !user.permissions.contains('budidaya:read') ||
        !user.permissions.contains('budidaya:write') ||
        !_matchesCurrentScope) {
      return;
    }
    final retained = _commands[_scope];
    if (retained != null && !identical(retained, _command)) {
      _restoreCommand(retained);
      _commandChanged();
      if (_submitting || _saved) return;
    }
    if (_pendingTransfer == null) {
      if (!_formKey.currentState!.validate() || table == null) return;
      final firstDate = _firstDate;
      if (!widget.sowingRecord.canTransfer ||
          firstDate == null ||
          _date.isBefore(firstDate) ||
          _date.isAfter(_today)) {
        setState(() {
          _error = 'Pilih tanggal setelah 15 hari semai hingga hari ini.';
        });
        return;
      }
      _command = SeedlingTransferCommand((
        idempotencyKey: generateUuidV4(),
        sowingId: widget.sowingRecord.id,
        tableId: table.id,
        transferDate: _formatDate(_date),
        plantCount: int.parse(_quantity.text.trim()),
        note: _note.text.trim(),
      ));
      _commands[_scope!] = _command!;
      _command!.addListener(_commandChanged);
    }
    final command = _command!;
    final scope = _scope!;
    final nursery = ref.read(connectedNurseryProvider.notifier);
    _error = null;
    try {
      await nursery.submitTransfer(command);
    } catch (error) {
      final rejected = command.rejected;
      if (rejected && identical(_commands[scope], command)) {
        _commands.remove(scope);
      }
      if (mounted) {
        setState(() {
          _error = serviceError(error);
          if (rejected) {
            command.removeListener(_commandChanged);
            _command = null;
          }
        });
      }
      return;
    }
    if (!mounted) return;
    await _acknowledgeSave();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    final currentOrigin = ref.watch(apiClientProvider).serverOrigin;
    if (user == null ||
        !user.permissions.contains('penyemaian:read') ||
        !user.permissions.contains('penyemaian:write') ||
        !user.permissions.contains('budidaya:read') ||
        !user.permissions.contains('budidaya:write') ||
        _scope != (currentOrigin, user.id, widget.sowingRecord.id)) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Anda tidak memiliki akses pemindahan.'),
        ),
      );
    }
    final tablesState = ref.watch(connectedTableProvider);
    final nurseryState = ref.watch(connectedNurseryProvider);
    final tables = tablesState.records
        .where((table) => table.isAvailable && table.availableCapacity > 0)
        .toList();
    final selected = tables.where((table) => table.id == _tableId).firstOrNull;
    final busy = _submitting || _refreshing;
    final locked = _submitting || (_pendingTransfer != null && !_saved);
    final pending = _pendingTransfer;
    final error = _command?.error ?? _error;

    return PopScope(
      canPop: !locked,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pindahkan ke Meja',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(widget.sowingRecord.batchName),
                const SizedBox(height: 20),
                if (_saved) ...[
                  const Text('Pemindahan berhasil disimpan.'),
                  if (_command?.receipt case final receipt?)
                    Text(
                      'Batch #${receipt.id}: ${receipt.activePlants} tanaman aktif.',
                    ),
                  if (_refreshing) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const Text('Memperbarui data penyemaian dan meja...'),
                  ],
                  if (_refreshError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _refreshError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                      ),
                      onPressed: busy ? null : _refreshData,
                      child: const Text('Muat ulang data'),
                    ),
                  ],
                ] else if (tablesState.loading && pending == null) ...[
                  const LinearProgressIndicator(),
                  const Text('Memuat meja...'),
                ] else if (tablesState.error != null && pending == null) ...[
                  Text(
                    tablesState.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () =>
                        ref.read(connectedTableProvider.notifier).refresh(),
                    child: const Text('Coba lagi'),
                  ),
                ] else if (tables.isEmpty && pending == null) ...[
                  const Text('Belum ada meja dengan kapasitas tersedia.'),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () =>
                        ref.read(connectedTableProvider.notifier).refresh(),
                    child: const Text('Muat ulang meja'),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: pending?.tableId ?? selected?.id,
                    isExpanded: true,
                    itemHeight: null,
                    selectedItemBuilder: (_) => [
                      ...tables.map(
                        (table) => Text(
                          table.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pending != null && selected == null)
                        Text('Meja ${pending.tableId}'),
                    ],
                    decoration: const InputDecoration(labelText: 'Meja tujuan'),
                    items: [
                      ...tables.map(
                        (table) => DropdownMenuItem(
                          value: table.id,
                          child: Text(
                            '${table.displayName} (${table.availableCapacity} tersedia)',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (pending != null && selected == null)
                        DropdownMenuItem(
                          value: pending.tableId,
                          child: Text('Meja ${pending.tableId}'),
                        ),
                    ],
                    onChanged: locked
                        ? null
                        : (value) => setState(() => _tableId = value),
                    validator: (_) =>
                        selected == null ? 'Pilih meja tujuan.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantity,
                    enabled: !locked,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Jumlah tanaman',
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                      helperText: selected == null
                          ? null
                          : 'Kapasitas tersedia: ${selected.availableCapacity} tanaman',
                    ),
                    validator: (value) {
                      final count = int.tryParse(value?.trim() ?? '');
                      if (count == null || count <= 0) {
                        return 'Jumlah tanaman harus lebih dari 0.';
                      }
                      if (count > widget.sowingRecord.remainingSeedCount) {
                        return 'Sisa bibit tersedia: ${widget.sowingRecord.remainingSeedCount}.';
                      }
                      if (selected != null &&
                          count > selected.availableCapacity) {
                        return 'Maksimal ${selected.availableCapacity} tanaman untuk meja ini.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: locked ? null : _chooseDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Tanggal pemindahan: ${_formatDate(_date)}'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Estimasi panen (45 HSS): ${_formatDate(DateTime.parse(widget.sowingRecord.sowingDate).add(const Duration(days: 45)))}',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _note,
                    enabled: !locked,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                    ),
                    maxLines: 2,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    if (_pendingTransfer != null)
                      const Text(
                        'Hasil pemindahan belum pasti. Simpan kembali untuk '
                        'mengulang permintaan yang sama dengan aman.',
                      ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.darkNavy,
                      foregroundColor: AppColors.accentLime,
                      minimumSize: const Size(44, 52),
                    ),
                    onPressed: busy || (nurseryState.loading && pending == null)
                        ? null
                        : () => _submit(selected),
                    child: Text(
                      _submitting ? 'Menyimpan...' : 'Simpan pemindahan',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: busy || locked
                      ? null
                      : () => Navigator.pop(context),
                  child: Text(_saved ? 'Selesai' : 'Batal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
