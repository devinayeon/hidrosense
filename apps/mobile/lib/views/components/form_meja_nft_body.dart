import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/table_record.dart';
import '../../models/meja_nft_model.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/row_button.dart';

class FormMejaNftBody extends ConsumerStatefulWidget {
  final TableRecord? tableRecord;
  final MejaNft? mejaItem;

  const FormMejaNftBody({
    super.key,
    this.tableRecord,
    this.mejaItem,
  });

  @override
  ConsumerState<FormMejaNftBody> createState() => _FormMejaNftBodyState();
}

class _FormMejaNftBodyState extends ConsumerState<FormMejaNftBody> {
  late TextEditingController _codeController;
  late TextEditingController _capacityController;
  late TextEditingController _notesController;
  String _selectedStatus = 'tersedia';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final rec = widget.tableRecord;
    final item = widget.mejaItem;
    _codeController = TextEditingController(text: rec?.code ?? item?.name ?? '');
    _capacityController = TextEditingController(
      text: (rec?.holeCount ?? item?.capacityTotal ?? 250).toString(),
    );
    _notesController = TextEditingController(text: rec?.notes ?? item?.notes ?? '');
    _selectedStatus = rec?.status ??
        (item?.status == MejaStatus.perawatan ? 'pemeliharaan' : 'tersedia');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _capacityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    final code = _codeController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 0;
    final notes = _notesController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode / Nama Meja tidak boleh kosong')),
      );
      return;
    }
    if (capacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kapasitas lubang harus lebih dari 0')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final rec = widget.tableRecord;
      if (rec == null) {
        await ref.read(connectedTableProvider.notifier).createTable(
              code: code,
              holeCount: capacity,
              status: _selectedStatus,
              notes: notes.isNotEmpty ? notes : null,
            );
      } else {
        await ref.read(connectedTableProvider.notifier).updateTable(
              rec.id,
              code: code,
              holeCount: capacity,
              status: _selectedStatus,
              notes: notes.isNotEmpty ? notes : null,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rec == null ? 'Meja tanam berhasil ditambahkan' : 'Meja tanam berhasil diperbarui',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan meja: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomInputField(
              label: 'Kode / Nama Meja',
              hintText: 'Contoh: M-01 atau Meja NFT #01',
              controller: _codeController,
            ),
            const SizedBox(height: 16),
            CustomInputField(
              label: 'Kapasitas Lubang Default',
              hintText: '250',
              controller: _capacityController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text(
              'Status Meja Utama',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color.fromRGBO(23, 34, 49, 1),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color.fromRGBO(229, 231, 235, 1),
                  width: 1.2,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Color.fromRGBO(156, 163, 175, 1)),
                  items: const [
                    DropdownMenuItem(value: 'tersedia', child: Text('Tersedia / Aktif')),
                    DropdownMenuItem(value: 'pemeliharaan', child: Text('Perawatan')),
                    DropdownMenuItem(value: 'penuh', child: Text('Penuh')),
                    DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedStatus = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomInputField(
              label: 'Catatan / Spesifikasi',
              hintText: 'Merek pompa, debit air, tipe pipa PVC',
              controller: _notesController,
            ),
            const SizedBox(height: 24),
            RowButton(
              label: _submitting
                  ? 'Menyimpan...'
                  : widget.tableRecord == null
                      ? 'Simpan Meja'
                      : 'Perbarui Pengaturan Meja',
              backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
              textColor: const Color.fromRGBO(221, 244, 90, 1),
              borderRadius: 24,
              height: 52,
              onTap: _submitting ? () {} : _saveForm,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
