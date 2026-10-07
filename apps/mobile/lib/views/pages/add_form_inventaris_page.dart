import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/inventory_record.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../components/header.dart';
import '../widgets/row_button.dart';

class AddFormInventarisPage extends ConsumerStatefulWidget {
  final InventoryRecord? initialRecord;
  const AddFormInventarisPage({super.key, this.initialRecord});

  bool get isEditMode => initialRecord != null;

  @override
  ConsumerState<AddFormInventarisPage> createState() =>
      _AddFormInventarisPageState();
}

class _AddFormInventarisPageState extends ConsumerState<AddFormInventarisPage> {
  late TextEditingController _nameController;
  late TextEditingController _stockController;
  late TextEditingController _minimumController;

  String? _selectedCategory;
  String? _selectedUnit;
  bool _saving = false;

  final Map<String, String> _categoryMap = {
    'Benih': '1',
    'Pupuk': '2',
    'Obat': '3',
    'Peralatan': '4',
    'Media Tanam': '5',
  };

  final List<String> _units = [
    'Kg',
    'Gram',
    'Liter',
    'Ml',
    'btr',
    'Pcs',
    'Blok',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initialRecord;
    _nameController = TextEditingController(text: item?.name ?? '');
    _stockController = TextEditingController(text: item?.balance ?? '');
    _minimumController = TextEditingController(text: item?.minimum ?? '');

    if (item?.category != null && _categoryMap.containsKey(item!.category)) {
      _selectedCategory = item.category;
    }
    if (item?.unit != null) {
      final match = _units.firstWhere(
        (u) => u.toLowerCase() == item!.unit.toLowerCase(),
        orElse: () => item!.unit,
      );
      if (!_units.contains(match)) _units.add(match);
      _selectedUnit = match;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _minimumController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama barang tidak boleh kosong')),
      );
      return;
    }

    final categoryId = _categoryMap[_selectedCategory ?? 'Benih'] ?? '1';
    final unit = _selectedUnit ?? 'Pcs';
    final minimum = _minimumController.text.trim();
    final initialStock = _stockController.text.trim();

    setState(() => _saving = true);
    try {
      final user = ref.read(sessionProvider).user;
      if (user == null) throw StateError('Sesi tidak aktif');
      final repo = InventoryRepository(
        ref.read(apiClientProvider),
        ref.read(inventoryCacheProvider),
        userId: user.id,
      );

      if (widget.isEditMode) {
        await repo.updateItem(
          widget.initialRecord!.id,
          name: name,
          categoryId: categoryId,
          unit: unit,
          minimum: minimum,
        );
      } else {
        final created = await repo.createItem(
          name: name,
          categoryId: categoryId,
          unit: unit,
          minimum: minimum,
        );
        final stockVal = double.tryParse(initialStock) ?? 0;
        if (stockVal > 0) {
          await repo.recordStockMovement(
            direction: 'masuk',
            details: [
              {
                'id_inventaris': created.id,
                'jumlah': initialStock,
                'satuan': unit,
              },
            ],
            note: 'Saldo awal registrasi barang',
          );
        }
      }

      await ref.read(connectedInventoryProvider.notifier).refresh();
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: ${serviceError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        titleText: widget.isEditMode ? 'Edit Barang' : 'Tambah Barang Baru',
        showBackButton: true,
      ),
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Nama Barang'),
            const SizedBox(height: 6),
            _textField(_nameController, 'Contoh: Benih Selada Bataviya'),
            const SizedBox(height: 16),
            _label('Kategori'),
            const SizedBox(height: 6),
            _dropdown<String>(
              value: _selectedCategory,
              hintText: 'Pilih Kategori Barang',
              items: _categoryMap.keys.toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Stok Awal'),
                      const SizedBox(height: 6),
                      _textField(
                        _stockController,
                        '0',
                        keyboardType: TextInputType.number,
                        readOnly: widget.isEditMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Satuan'),
                      const SizedBox(height: 6),
                      _dropdown<String>(
                        value: _selectedUnit,
                        hintText: 'Satuan',
                        items: _units,
                        onChanged: (val) => setState(() => _selectedUnit = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label('Stok Minimum (Peringatan)'),
            const SizedBox(height: 6),
            _textField(
              _minimumController,
              'Contoh: 5 (Opsional)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 28),
            RowButton(
              label: _saving
                  ? 'Menyimpan...'
                  : (widget.isEditMode ? 'Simpan Perubahan' : 'Simpan Barang'),
              backgroundColor: const Color.fromRGBO(57, 198, 195, 1),
              textColor: Colors.white,
              borderRadius: 100.0,
              height: 52.0,
              onTap: _saving ? null : _saveForm,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
  );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) => Container(
    decoration: BoxDecoration(
      color: readOnly ? const Color.fromRGBO(245, 245, 242, 1) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color.fromRGBO(229, 231, 235, 1)),
    ),
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14,
          color: Color.fromRGBO(156, 163, 175, 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: InputBorder.none,
      ),
    ),
  );

  Widget _dropdown<T>({
    required T? value,
    required String hintText,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color.fromRGBO(229, 231, 235, 1)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: Text(
          hintText,
          style: const TextStyle(
            fontSize: 13,
            color: Color.fromRGBO(156, 163, 175, 1),
          ),
        ),
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color.fromRGBO(156, 163, 175, 1),
        ),
        items: items
            .map(
              (T item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString(),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}
