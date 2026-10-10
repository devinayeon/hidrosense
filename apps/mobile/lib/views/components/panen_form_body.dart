import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/business_date.dart';
import '../../data/models/harvest_draft.dart';
import '../../data/models/harvest_record.dart';
import '../../viewmodels/panen_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';

class PanenFormBody extends ConsumerStatefulWidget {
  const PanenFormBody({super.key, this.harvestId, this.transferId});
  final String? harvestId, transferId;
  @override
  ConsumerState<PanenFormBody> createState() => _FormState();
}

class _RowControllers {
  _RowControllers({
    this.id,
    String count = '',
    String total = '',
    String reject = '',
  }) : count = TextEditingController(text: count),
       total = TextEditingController(text: total),
       reject = TextEditingController(text: reject);
  String? id;
  final TextEditingController count, total, reject;
  void dispose() {
    count.dispose();
    total.dispose();
    reject.dispose();
  }
}

class _FormState extends ConsumerState<PanenFormBody> {
  final _note = TextEditingController();
  final _rows = <_RowControllers>[];
  String? _date, _version;
  bool _initialized = false;
  HarvestReadState? _initialDetail;
  bool _correctWeights = false;
  bool get _editing => widget.harvestId != null;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final user = ref.read(sessionProvider).user;
      if (user == null ||
          !user.permissions.contains('panen:read') ||
          !user.permissions.contains('panen:write')) {
        return;
      }
      final vm = ref.read(panenViewModelProvider.notifier);
      vm.beginDraft();
      if (_editing) _loadInitialDetail(vm);
    });
  }

  Future<void> _loadInitialDetail(PanenViewModel vm) async {
    setState(() => _initialDetail = const HarvestReadState(loading: true));
    final result = await vm.loadDetail(widget.harvestId!);
    if (!mounted) return;
    setState(
      () => _initialDetail =
          result ??
          const HarvestReadState(error: 'Data panen berubah. Coba lagi.'),
    );
  }

  void _initialize(PanenViewModel vm, HarvestRecord? record) {
    if (_initialized || (_editing && record == null)) return;
    _initialized = true;
    _date = record?.date ?? apiDate(vm.today);
    _version = record?.version;
    _note.text = record?.note ?? '';
    final pending = vm.pendingCommand;
    if (pending?.target == (_editing ? widget.harvestId : 'create') &&
        vm.payloadLocked) {
      _note.text = (pending!.body['keterangan'] as String?) ?? '';
      _date = (pending.body['tanggal_panen'] as String?) ?? _date;
      _version = (pending.body['expected_version'] as String?) ?? _version;
      final details = pending.body['details'] as List?;
      _correctWeights = _editing && details != null;
      if (details != null) {
        for (final row in details) {
          _rows.add(
            _RowControllers(
              id: row[_editing ? 'id_detail_panen' : 'id_pemindahan'],
              count: '${row['jumlah_tanaman'] ?? ''}',
              total: row['berat_total'],
              reject: row['berat_reject'],
            ),
          );
        }
      }
    }
    if (_rows.isEmpty) {
      if (record != null) {
        for (final detail in record.details) {
          _rows.add(
            _RowControllers(
              id: detail.id,
              count: '${detail.plantCount}',
              total: detail.total?.wire ?? '',
              reject: detail.reject?.wire ?? '',
            ),
          );
        }
      } else {
        _rows.add(_RowControllers(id: widget.transferId));
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(PanenViewModel vm) async {
    var minimum = DateTime(2000);
    for (final row in _rows) {
      final batch = vm.current.transfers
          .where((b) => b.id == row.id)
          .firstOrNull;
      if (batch != null &&
          DateTime.parse(batch.transferDate).isAfter(minimum)) {
        minimum = DateTime.parse(batch.transferDate);
      }
    }
    if (minimum.isAfter(vm.today)) return;
    final current = DateTime.parse(_date!);
    final result = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.inputOnly,
      firstDate: minimum,
      lastDate: vm.today,
      initialDate: current.isBefore(minimum)
          ? minimum
          : current.isAfter(vm.today)
          ? vm.today
          : current,
    );
    if (mounted && result != null) setState(() => _date = apiDate(result));
  }

  Future<void> _save(PanenViewModel vm) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = vm.payloadLocked
        ? await vm.retryPending()
        : _editing
        ? await vm.correct(
            HarvestCorrection(
              id: widget.harvestId!,
              expectedVersion: _version ?? '',
              note: _note.text,
              rows: _correctWeights
                  ? _rows
                        .map(
                          (r) => HarvestCorrectionRow(
                            detailId: r.id!,
                            total: r.total.text,
                            reject: r.reject.text,
                          ),
                        )
                        .toList()
                  : null,
            ),
          )
        : await vm.submit(
            HarvestDraft(
              date: _date!,
              note: _note.text,
              rows: _rows
                  .map(
                    (r) => HarvestDraftRow(
                      transferId: r.id ?? '',
                      plantCount: int.tryParse(r.count.text) ?? 0,
                      total: r.total.text,
                      reject: r.reject.text,
                    ),
                  )
                  .toList(),
            ),
          );
    if (!mounted) return;
    if (result == HarvestSubmitResult.saved ||
        result == HarvestSubmitResult.savedRefreshFailed) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result == HarvestSubmitResult.saved
                ? 'Hasil panen tersimpan.'
                : vm.current.refreshWarning ??
                      'Tersimpan. Muat ulang data terbaru.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } else if (result == HarvestSubmitResult.failed) {
      messenger.showSnackBar(
        SnackBar(content: Text(vm.current.error ?? 'Periksa isian panen.')),
      );
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    bool enabled, {
    bool decimal = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextField(
      controller: controller,
      enabled: enabled,
      maxLines: lines,
      keyboardType: lines > 1
          ? TextInputType.multiline
          : TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final permissions =
        ref.watch(sessionProvider).user?.permissions ?? <String>[];
    if (!permissions.contains('panen:read') ||
        !permissions.contains('panen:write') ||
        (!_editing && !permissions.contains('budidaya:read'))) {
      return const Center(child: Text('Akses panen tidak diizinkan.'));
    }
    final state = ref.watch(panenViewModelProvider);
    final vm = ref.read(panenViewModelProvider.notifier);
    final detailRead = _initialDetail;
    final record = detailRead?.record;
    final reviewRecord = state.records
        .where((r) => r.id == widget.harvestId)
        .firstOrNull;
    _initialize(vm, record);
    if (!_initialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(detailRead?.error ?? 'Memuat panen...'),
            if (vm.payloadLocked &&
                vm.pendingCommand?.target == widget.harvestId) ...[
              Text(
                'Request koreksi panen #${widget.harvestId} belum pasti. Ulangi request yang sama untuk menyelesaikannya.',
              ),
              FilledButton(
                onPressed: state.submitting ? null : () => _save(vm),
                child: const Text('Ulangi Request yang Sama'),
              ),
            ],
            if (detailRead?.error != null)
              TextButton(
                onPressed: () => _loadInitialDetail(vm),
                child: const Text('Coba lagi'),
              ),
          ],
        ),
      );
    }
    final enabled = !state.submitting && !vm.payloadLocked;
    final wrongPending =
        vm.payloadLocked &&
        vm.pendingCommand?.target != (_editing ? widget.harvestId : 'create');
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        if (state.loading) const Text('Memuat batch dan data panen...'),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (state.refreshWarning != null) Text(state.refreshWarning!),
        if (_editing && detailRead?.error != null) Text(detailRead!.error!),
        if (vm.payloadLocked)
          Text(
            wrongPending
                ? 'Request panen lain belum pasti. Buka form sebelumnya untuk menyelesaikannya.'
                : 'Hasil request belum pasti. Isian terkunci sampai request yang sama selesai.',
          ),
        if (state.conflictId == widget.harvestId && _editing) ...[
          const Text(
            'Panen telah berubah. Isian Anda dipertahankan. Tinjau data terbaru sebelum menyimpan.',
          ),
          Text(
            'Versi terbaru ${reviewRecord?.version ?? 'belum tersedia'} • Layak ${reviewRecord?.saleable.wire ?? 'belum tersedia'} kg',
          ),
          TextButton(
            onPressed: reviewRecord?.version == null
                ? null
                : () {
                    setState(() => _version = reviewRecord!.version);
                    vm.acknowledgeConflict(widget.harvestId!);
                  },
            child: const Text('Saya sudah meninjau data terbaru'),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: enabled && !_editing ? () => _pickDate(vm) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Tanggal panen: $_date'),
          ),
        ),
        if (_editing)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Koreksi berat sortasi'),
            subtitle: const Text('Tanggal, batch, dan jumlah tanaman tetap.'),
            value: _correctWeights,
            onChanged: enabled
                ? (value) => setState(() => _correctWeights = value)
                : null,
          ),
        for (var index = 0; index < _rows.length; index++)
          _buildRow(index, vm, record, enabled),
        if (!_editing && _rows.length < 100)
          TextButton.icon(
            onPressed: enabled
                ? () => setState(() => _rows.add(_RowControllers()))
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Batch'),
          ),
        _field('Catatan panen', _note, enabled, lines: 3),
        const SizedBox(height: 24),
        FilledButton(
          onPressed:
              state.submitting || wrongPending || (_editing && _version == null)
              ? null
              : () => _save(vm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              state.submitting
                  ? 'Menyimpan...'
                  : vm.payloadLocked
                  ? 'Ulangi Request yang Sama'
                  : _editing
                  ? 'Simpan Koreksi'
                  : 'Simpan Hasil Panen',
            ),
          ),
        ),
        if (state.error != null && !vm.payloadLocked)
          TextButton(
            onPressed: vm.refresh,
            child: const Text('Muat ulang data'),
          ),
      ],
    );
  }

  Widget _buildRow(
    int index,
    PanenViewModel vm,
    HarvestRecord? record,
    bool enabled,
  ) {
    final row = _rows[index];
    final batch = vm.current.transfers.where((b) => b.id == row.id).firstOrNull;
    final detail = record?.details.where((d) => d.id == row.id).firstOrNull;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Batch ${index + 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_editing)
              Text(
                '${detail?.tableCode ?? ''} • Meja #${detail?.tableId ?? ''} • Batch #${detail?.transferId ?? ''}\n${detail?.plantCount ?? ''} tanaman',
              )
            else ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ObjectKey(row),
                initialValue: batch?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pilih batch aktif',
                  border: OutlineInputBorder(),
                ),
                items: vm.current.transfers
                    .where(
                      (b) =>
                          b.id == row.id ||
                          (b.activePlants > 0 &&
                              !_rows.any((r) => r.id == b.id)),
                    )
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          '#${b.id} • Meja #${b.tableId}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: enabled
                    ? (value) => setState(() => row.id = value)
                    : null,
              ),
              if (batch != null)
                Text(
                  'Batch #${batch.id} • Meja #${batch.tableId}\n${batch.activePlants} tanaman aktif • Pindah ${batch.transferDate}\nHSS ${batch.hss ?? 'belum tersedia'} • HST ${batch.hst ?? 'belum tersedia'}',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              _field('Jumlah', row.count, enabled),
            ],
            if (!_editing || _correctWeights) ...[
              _field('Berat total (kg)', row.total, enabled, decimal: true),
              _field('Berat reject (kg)', row.reject, enabled, decimal: true),
            ],
            if (_editing && detail?.total == null)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Sortasi lama belum tercatat. Isi kedua berat untuk koreksi, atau simpan catatan saja.',
                ),
              ),
            if (!_editing && _rows.length > 1)
              TextButton(
                onPressed: enabled
                    ? () {
                        setState(() => _rows.removeAt(index));
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => row.dispose(),
                        );
                      }
                    : null,
                child: const Text('Hapus Batch'),
              ),
          ],
        ),
      ),
    );
  }
}
