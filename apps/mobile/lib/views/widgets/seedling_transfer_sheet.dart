import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/nursery_record.dart';
import '../../data/models/table_record.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';

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
    if (_submitting ||
        _saved ||
        !_formKey.currentState!.validate() ||
        table == null) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(connectedNurseryProvider.notifier)
          .transferSowing(
            sowingId: widget.sowingRecord.id,
            tableId: table.id,
            transferDate: _formatDate(_date),
            plantCount: int.parse(_quantity.text.trim()),
            note: _note.text.trim(),
          );
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = serviceError(error);
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

    return PopScope(
      canPop: !_submitting,
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
                    onChanged: busy
                        ? null
                        : (value) => setState(() => _tableId = value),
                    validator: (_) =>
                        selected == null ? 'Pilih meja tujuan.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantity,
                    enabled: !busy,
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
                      if (selected != null &&
                          count > selected.availableCapacity) {
                        return 'Maksimal ${selected.availableCapacity} tanaman untuk meja ini.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _chooseDate,
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
                    enabled: !busy,
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
                  onPressed: busy ? null : () => Navigator.pop(context),
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
