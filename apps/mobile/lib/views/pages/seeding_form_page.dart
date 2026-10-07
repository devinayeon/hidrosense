import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/nursery_record.dart';
import '../../models/seeding_batch_model.dart';
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../components/header.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/row_button.dart';

class SeedingFormPage extends ConsumerStatefulWidget {
  final SowingRecord? sowingRecord;
  final SeedingBatch? seedingItem;

  const SeedingFormPage({super.key, this.sowingRecord, this.seedingItem});

  bool get isEditMode => sowingRecord != null || seedingItem != null;

  @override
  ConsumerState<SeedingFormPage> createState() => _SeedingFormPageState();
}

class _SeedingFormPageState extends ConsumerState<SeedingFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateController;
  late TextEditingController _seedCountController;
  late TextEditingController _noteController;

  String? _selectedInventoryId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.sowingRecord;
    final legacy = widget.seedingItem;
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    _dateController = TextEditingController(
      text: item?.sowingDate ?? legacy?.dateText ?? todayStr,
    );
    _seedCountController = TextEditingController(
      text: (item?.seedCount ?? legacy?.healthyCount ?? 100).toString(),
    );
    _noteController = TextEditingController(
      text: item?.note ?? legacy?.damagedNote ?? '',
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _seedCountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final dateText = _dateController.text.trim();
    final seedCount = int.tryParse(_seedCountController.text.trim()) ?? 0;
    final note = _noteController.text.trim();

    if (dateText.isEmpty || seedCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal dan jumlah benih harus valid!')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (widget.sowingRecord != null) {
        await ref
            .read(connectedNurseryProvider.notifier)
            .updateStatus(widget.sowingRecord!.id, 'aktif');
      } else {
        final invId = _selectedInventoryId ?? '1';
        await ref
            .read(connectedNurseryProvider.notifier)
            .createSowing(
              sowingDate: dateText,
              seedCount: seedCount,
              note: note.isEmpty ? null : note,
              materials: [
                {
                  'id_inventaris': invId,
                  'jumlah': seedCount.toString(),
                  'satuan': 'btr',
                },
              ],
            );
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan penyemaian: ${serviceError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEditMode;
    final inventoryState = ref.watch(connectedInventoryProvider);
    final seedItems = inventoryState.records
        .where((i) => i.category.toLowerCase().contains('benih') || i.active)
        .toList();

    return Scaffold(
      appBar: Header(
        titleText: isEdit ? 'Edit Penyemaian' : 'Penyemaian Baru',
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
              CustomInputField(
                label: 'Tanggal Semai (YYYY-MM-DD)',
                hintText: 'YYYY-MM-DD',
                controller: _dateController,
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _dateController.text =
                          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (!isEdit && seedItems.isNotEmpty) ...[
                const Text(
                  'Pilih Benih dari Inventaris',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color.fromRGBO(24, 29, 39, 1),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color.fromRGBO(229, 231, 235, 1),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedInventoryId ?? seedItems.first.id,
                      isExpanded: true,
                      items: seedItems.map((item) {
                        return DropdownMenuItem<String>(
                          value: item.id,
                          child: Text('${item.name} (${item.formattedStock})'),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedInventoryId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              CustomInputField(
                label: 'Jumlah Benih (Butir)',
                hintText: 'Contoh: 500',
                controller: _seedCountController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              CustomInputField(
                label: 'Catatan Penyemaian',
                hintText: 'Lokasi rak semai atau catatan batch',
                controller: _noteController,
              ),
              const SizedBox(height: 28),
              RowButton(
                label: _submitting
                    ? 'Menyimpan...'
                    : (isEdit ? 'Simpan Perubahan' : 'Mulai Semaian & Simpan'),
                backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
                textColor: const Color.fromRGBO(221, 244, 90, 1),
                height: 52,
                borderRadius: 20,
                onTap: _submitting ? null : _submitForm,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
