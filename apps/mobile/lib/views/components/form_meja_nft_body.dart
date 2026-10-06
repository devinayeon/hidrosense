// lib/views/components/form_meja_nft_body.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/meja_nft_model.dart';
import '../../viewmodels/meja_nft_viewmodel.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/row_button.dart';

class FormMejaNftBody extends ConsumerStatefulWidget {
  final MejaNft? mejaItem; // null = Mode Tambah, not null = Mode Edit

  const FormMejaNftBody({super.key, this.mejaItem});

  @override
  ConsumerState<FormMejaNftBody> createState() => _FormMejaNftBodyState();
}

class _FormMejaNftBodyState extends ConsumerState<FormMejaNftBody> {
  late TextEditingController _nameController;
  late TextEditingController _capacityController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;
  MejaStatus _selectedStatus = MejaStatus.aktif;

  @override
  void initState() {
    super.initState();
    final item = widget.mejaItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _capacityController = TextEditingController(
      text: item != null ? item.capacityTotal.toString() : '250',
    );
    _locationController = TextEditingController(text: item?.location ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
    _selectedStatus = item?.status ?? MejaStatus.aktif;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveForm() {
    final name = _nameController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 250;
    final location = _locationController.text.trim();
    final notes = _notesController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode / Nama Meja tidak boleh kosong')),
      );
      return;
    }

    if (widget.mejaItem == null) {
      // Mode Tambah
      final newMeja = MejaNft(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        location: location.isNotEmpty ? location : 'Lokasi Green House Barat',
        capacityTotal: capacity,
        status: _selectedStatus,
        notes: notes,
      );
      ref.read(mejaNftViewModelProvider.notifier).addMeja(newMeja);
    } else {
      // Mode Edit
      final updatedMeja = widget.mejaItem!.copyWith(
        name: name,
        location: location.isNotEmpty ? location : widget.mejaItem!.location,
        capacityTotal: capacity,
        status: _selectedStatus,
        notes: notes,
      );
      ref.read(mejaNftViewModelProvider.notifier).updateMeja(updatedMeja);
    }

    Navigator.pop(context);
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
            // 1. Kode / Nama Meja
            CustomInputField(
              label: 'Kode / Nama Meja',
              hintText: 'Contoh: Meja NFT #05',
              controller: _nameController,
            ),
            const SizedBox(height: 16),

            // 2. Kapasitas Lubang Default
            CustomInputField(
              label: 'Kapasitas Lubang Default',
              hintText: '250',
              controller: _capacityController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // 3. Lokasi Meja
            CustomInputField(
              label: 'Lokasi Meja',
              hintText: 'Contoh: Green House Timur, Baris 2',
              controller: _locationController,
            ),
            const SizedBox(height: 16),

            // 4. Status Meja Utama (Dropdown)
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
                child: DropdownButton<MejaStatus>(
                  value: _selectedStatus,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color.fromRGBO(156, 163, 175, 1),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: MejaStatus.aktif,
                      child: Text(
                        'Aktif',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                      ),
                    ),
                    DropdownMenuItem(
                      value: MejaStatus.perawatan,
                      child: Text(
                        'Perawatan',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Catatan / Spesifikasi
            CustomInputField(
              label: 'Catatan / Spesifikasi',
              hintText: 'Merek pompa, debit air, tipe pipa PVC',
              controller: _notesController,
            ),
            const SizedBox(height: 24),

            // 6. Tombol Simpan Meja
            RowButton(
              label: widget.mejaItem == null
                  ? 'Simpan Meja'
                  : 'Perbarui Pengaturan Meja',
              backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
              textColor: const Color.fromRGBO(221, 244, 90, 1),
              borderRadius: 24,
              height: 52,
              onTap: _saveForm,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
