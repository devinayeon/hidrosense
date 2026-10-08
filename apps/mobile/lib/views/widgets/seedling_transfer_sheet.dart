import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/nursery_record.dart';
import '../../data/models/table_record.dart';
import '../../data/services/api_client.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';

typedef _PendingTransfer = ({
  String idempotencyKey,
  String sowingId,
  String tableId,
  String transferDate,
  int plantCount,
  String note,
});

String _newIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

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
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  String? _tableId;
  String? _error;
  String? _refreshError;
  bool _submitting = false;
  bool _saved = false;
  bool _refreshing = false;
  _PendingTransfer? _pendingTransfer;

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _refreshData() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      await Future.wait([
        ref.read(connectedNurseryProvider.notifier).refresh(),
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
    if (_pendingTransfer == null) {
      if (!_formKey.currentState!.validate() || table == null) return;
      _pendingTransfer = (
        idempotencyKey: _newIdempotencyKey(),
        sowingId: widget.sowingRecord.id,
        tableId: table.id,
        transferDate: _formatDate(_date),
        plantCount: int.parse(_quantity.text.trim()),
        note: _note.text.trim(),
      );
    }
    final pending = _pendingTransfer!;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(connectedNurseryProvider.notifier)
          .transferSowing(
            idempotencyKey: pending.idempotencyKey,
            sowingId: pending.sowingId,
            tableId: pending.tableId,
            transferDate: pending.transferDate,
            plantCount: pending.plantCount,
            note: pending.note,
          );
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = serviceError(error);
          // Only a definite rejection permits a new operation and edited body.
          if (error is ApiException &&
              error.status >= 400 &&
              error.status < 500 &&
              error.code != 'SESSION_CHANGED') {
            _pendingTransfer = null;
          }
        });
      }
      return;
    }
    if (!mounted) return;
    // Commit success before refreshing: a failed GET must never retry the POST.
    setState(() {
      _saved = true;
      _submitting = false;
    });
    widget.onTransferred();
    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final tablesState = ref.watch(connectedTableProvider);
    final nurseryState = ref.watch(connectedNurseryProvider);
    final tables = tablesState.records
        .where((table) => table.isAvailable && table.availableCapacity > 0)
        .toList();
    final selected = tables.where((table) => table.id == _tableId).firstOrNull;
    final busy = _submitting || _refreshing;
    final locked = _submitting || (_pendingTransfer != null && !_saved);

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
                      onPressed: busy ? null : _refreshData,
                      child: const Text('Muat ulang data'),
                    ),
                  ],
                ] else if (tablesState.loading) ...[
                  const LinearProgressIndicator(),
                  const Text('Memuat meja...'),
                ] else if (tablesState.error != null) ...[
                  Text(
                    tablesState.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(connectedTableProvider.notifier).refresh(),
                    child: const Text('Coba lagi'),
                  ),
                ] else if (tables.isEmpty) ...[
                  const Text('Belum ada meja dengan kapasitas tersedia.'),
                  TextButton(
                    onPressed: () =>
                        ref.read(connectedTableProvider.notifier).refresh(),
                    child: const Text('Muat ulang meja'),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: selected?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Meja tujuan'),
                    items: tables
                        .map(
                          (table) => DropdownMenuItem(
                            value: table.id,
                            child: Text(
                              '${table.displayName} (${table.availableCapacity} tersedia)',
                            ),
                          ),
                        )
                        .toList(),
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
                    'Estimasi panen (+45 hari): ${_formatDate(_date.add(const Duration(days: 45)))}',
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
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
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
                    onPressed: busy || nurseryState.loading
                        ? null
                        : () => _submit(selected),
                    child: Text(
                      _submitting ? 'Menyimpan...' : 'Simpan pemindahan',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
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
