import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/seeding_batch_model.dart';
import '../../viewmodels/penyemaian_viewmodel.dart';
import '../components/header.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_dropdown_field.dart';
import '../widgets/row_button.dart';

class SeedingFormPage extends ConsumerStatefulWidget {
  final SeedingBatch? seedingItem; // null = Add Mode, non-null = Edit Mode

  const SeedingFormPage({super.key, this.seedingItem});

  @override
  ConsumerState<SeedingFormPage> createState() => _SeedingFormPageState();
}

class _SeedingFormPageState extends ConsumerState<SeedingFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _batchNameController;
  late TextEditingController _dateController;
  late TextEditingController _seedCountController;
  late TextEditingController _noteController;

  String? _selectedVariety;
  String? _selectedMedia;
  String? _selectedStatus;

  bool get isEditMode => widget.seedingItem != null;

  final List<String> _varieties = [
    'Selada Grand Rapids',
    'Selada RZ Lollo Bionda',
    'Kangkung Bangkok',
    'Pocai Green',
  ];

  final List<String> _mediaOptions = [
    'Rockwool / Cocopeat',
    'Rockwool',
    'Spons Tanam',
  ];

  final List<String> _statusOptions = [
    'Fase Pembibitan',
    'Siap Pindah Besok',
    'Sudah Pindah',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.seedingItem;

    _batchNameController = TextEditingController(text: item?.batchName ?? '');
    _dateController = TextEditingController(text: item?.dateText ?? '');
    _seedCountController = TextEditingController(
      text: item != null ? item.seedCount.toString() : '',
    );
    _noteController = TextEditingController(text: item?.note ?? '');

    _selectedVariety = item?.variety;
    _selectedStatus = item?.statusLabel ?? 'Fase Pembibitan';
  }

  @override
  void dispose() {
    _batchNameController.dispose();
    _dateController.dispose();
    _seedCountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submitForm() {
    final batchName = _batchNameController.text.trim();
    final dateText = _dateController.text.trim();
    final seedCount = int.tryParse(_seedCountController.text) ?? 0;
    final note = _noteController.text.trim();

    if (batchName.isEmpty || _selectedVariety == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi data utama!')),
      );
      return;
    }

    final viewModel = ref.read(penyemaianViewModelProvider.notifier);

    if (isEditMode) {
      final updatedBatch = SeedingBatch(
        id: widget.seedingItem!.id,
        batchName: batchName,
        variety: _selectedVariety!,
        dateText: dateText,
        seedCount: seedCount,
        hss: widget.seedingItem!.hss,
        totalHss: widget.seedingItem!.totalHss,
        healthyCount: widget.seedingItem!.healthyCount,
        healthyPhase: widget.seedingItem!.healthyPhase,
        damagedCount: widget.seedingItem!.damagedCount,
        damagedNote: widget.seedingItem!.damagedNote,
        materials: widget.seedingItem!.materials,
        statusLabel: _selectedStatus ?? widget.seedingItem!.statusLabel,
        note: note,
      );
      viewModel.updateBatch(updatedBatch);
    } else {
      final newBatch = SeedingBatch(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        batchName: batchName,
        variety: _selectedVariety!,
        dateText: dateText.isNotEmpty ? dateText : 'Hari ini',
        seedCount: seedCount,
        hss: 0,
        totalHss: 15,
        statusLabel: _selectedStatus ?? 'Fase Pembibitan',
        note: note,
      );
      viewModel.addBatch(newBatch);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        titleText: isEditMode ? 'Edit Penyemaian' : 'Penyemaian Baru',
        showBackButton: true,
      ),
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- NAMA BATCH SEMAI ---
              CustomInputField(
                label: 'Nama Batch Semai',
                hintText: 'Contoh: Batch #06',
                controller: _batchNameController,
              ),
              const SizedBox(height: 16),

              // --- TANGGAL SEMAI ---
              CustomInputField(
                label: 'Tanggal Semai',
                hintText: isEditMode
                    ? '01 November 2024'
                    : 'Masukkan Tanggal (Hari ini)',
                controller: _dateController,
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _dateController.text =
                          "${picked.day.toString().padLeft(2, '0')} Nov ${picked.year}";
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // --- VARIETAS BENIH ---
              CustomDropdownField(
                label: 'Varietas Benih',
                hintText: 'Pilih benih dari inventaris',
                value: _selectedVariety,
                items: _varieties,
                onChanged: (val) => setState(() => _selectedVariety = val),
              ),
              const SizedBox(height: 16),

              // --- BARIS DUA COLUMN (JUMLAH & MEDIA/STATUS) ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomInputField(
                      label: isEditMode ? 'Jumlah Bibit' : 'Jumlah Benih (Btr)',
                      hintText: 'Contoh: 500',
                      controller: _seedCountController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isEditMode
                        ? CustomDropdownField(
                            label: 'Status',
                            hintText: 'Pilih Status',
                            value: _selectedStatus,
                            items: _statusOptions,
                            onChanged: (val) =>
                                setState(() => _selectedStatus = val),
                          )
                        : CustomDropdownField(
                            label: 'Media Tanam',
                            hintText: 'Rockwool / Coc...',
                            value: _selectedMedia,
                            items: _mediaOptions,
                            onChanged: (val) =>
                                setState(() => _selectedMedia = val),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- CATATAN ---
              CustomInputField(
                label: isEditMode ? 'Catatan Tambahan' : 'Catatan Penyemaian',
                hintText: 'Lokasi rak semai atau perlakuan khusus',
                controller: _noteController,
              ),
              const SizedBox(height: 28),

              // --- ROW BUTTON (TOMBOL UTAMA) ---
              RowButton(
                label: isEditMode
                    ? 'Simpan Perubahan'
                    : 'Mulai Semaian & Simpan',
                backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
                textColor: const Color.fromRGBO(221, 244, 90, 1),
                height: 52,
                borderRadius: 20,
                onTap: _submitForm,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
