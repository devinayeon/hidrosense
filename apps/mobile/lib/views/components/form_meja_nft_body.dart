import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/table_record.dart';
import '../../models/meja_nft_model.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_input_field.dart';

class FormMejaNftBody extends ConsumerStatefulWidget {
  const FormMejaNftBody({super.key, this.tableRecord, this.mejaItem});
  final TableRecord? tableRecord;
  final MejaNft? mejaItem;
  @override
  ConsumerState<FormMejaNftBody> createState() => _FormMejaNftBodyState();
}

class _FormMejaNftBodyState extends ConsumerState<FormMejaNftBody> {
  late final TextEditingController _codeController,
      _capacityController,
      _notesController;
  late String _selectedStatus;
  bool _submitting = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final rec = widget.tableRecord, item = widget.mejaItem;
    _codeController = TextEditingController(
      text: rec?.code ?? item?.name ?? '',
    );
    _capacityController = TextEditingController(
      text: '${rec?.holeCount ?? item?.capacityTotal ?? 250}',
    );
    _notesController = TextEditingController(
      text: rec?.notes ?? item?.notes ?? '',
    );
    _selectedStatus =
        rec?.status ??
        (item?.status == MejaStatus.perawatan ? 'pemeliharaan' : 'tersedia');
    final user = ref.read(sessionProvider).user;
    if (user?.permissions.contains('budidaya:write') == true) {
      final command = ref.read(connectedTableProvider.notifier).pendingCommand;
      if (command?.uncertain == true &&
          command?.target == (rec?.id ?? 'create')) {
        _codeController.text = command!.body['kode_meja'] as String? ?? '';
        _capacityController.text = '${command.body['jumlah_lubang']}';
        _notesController.text = command.body['keterangan'] as String? ?? '';
        _selectedStatus =
            command.body['status_meja'] as String? ?? _selectedStatus;
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _capacityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_submitting) return;
    final user = ref.read(sessionProvider).user;
    if (user?.permissions.contains('budidaya:write') != true) return;
    final code = _codeController.text.trim(),
        notes = _notesController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 0;
    if (code.isEmpty ||
        code.length > 30 ||
        capacity <= 0 ||
        capacity > 9007199254740991 ||
        notes.length > 1000) {
      setState(
        () => _error =
            'Isi kode 1–30 karakter, kapasitas positif, dan catatan maksimal 1000 karakter.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final vm = ref.read(connectedTableProvider.notifier);
    try {
      final rec = widget.tableRecord;
      if (rec == null) {
        await vm.createTable(
          code: code,
          holeCount: capacity,
          status: _selectedStatus,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await vm.updateTable(
          rec.id,
          code: code,
          holeCount: capacity,
          status: _selectedStatus,
          notes: notes.isEmpty ? null : notes,
        );
      }
      if (!mounted || !identical(user, ref.read(sessionProvider).user)) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vm.refreshWarning == null
                ? (rec == null
                      ? 'Meja tanam berhasil ditambahkan'
                      : 'Meja tanam berhasil diperbarui')
                : 'Meja tersimpan. Data terbaru belum dapat dimuat.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted && identical(user, ref.read(sessionProvider).user)) {
        setState(() => _error = 'Gagal menyimpan meja: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions =
        ref.watch(sessionProvider).user?.permissions ?? const <String>[];
    if (!permissions.contains('budidaya:read') ||
        !permissions.contains('budidaya:write')) {
      return const Center(child: Text('Akses perubahan meja tidak diizinkan.'));
    }
    ref.watch(connectedTableProvider);
    final locked = ref.read(connectedTableProvider.notifier).payloadLocked;
    final statuses = <String, String>{
      'tersedia': 'Tersedia / Aktif',
      'pemeliharaan': 'Perawatan',
      'penuh': 'Penuh',
      'nonaktif': 'Nonaktif',
    };
    statuses.putIfAbsent(_selectedStatus, () => _selectedStatus);
    return PopScope(
      canPop: !_submitting,
      child: Container(
        color: AppColors.canvasWarm,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (locked)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Hasil belum pasti. Ulangi penyimpanan dengan isian yang sama.',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              AbsorbPointer(
                absorbing: _submitting || locked,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomInputField(
                      label: 'Kode / Nama Meja',
                      hintText: 'Contoh: M-01',
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
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      style: AppTypography.body,
                      dropdownColor: AppColors.cardSurface,
                      iconEnabledColor: AppColors.textSecondary,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        labelText: 'Status Meja Utama',
                        labelStyle: AppTypography.subheadline,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        filled: true,
                        fillColor: AppColors.cardSurface,
                        border: OutlineInputBorder(),
                      ),
                      items: statuses.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting || locked
                          ? null
                          : (s) => setState(() => _selectedStatus = s!),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomInputField(
                      label: 'Catatan / Spesifikasi',
                      hintText: 'Merek pompa, debit air, tipe pipa PVC',
                      controller: _notesController,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 52),
                  backgroundColor: AppColors.darkNavy,
                  foregroundColor: AppColors.accentLime,
                ),
                onPressed: _submitting ? null : _saveForm,
                child: Text(
                  _submitting
                      ? 'Menyimpan...'
                      : widget.tableRecord == null
                      ? 'Simpan Meja'
                      : 'Perbarui Pengaturan Meja',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
