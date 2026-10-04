import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_item_model.dart';
import '../../viewmodels/inventaris_viewmodel.dart';
import '../components/header.dart';
import '../widgets/item_image_placeholder.dart';
import '../widgets/row_button.dart';

class AddFormInventarisPage extends ConsumerStatefulWidget {
  final InventoryItem? initialItem;

  const AddFormInventarisPage({super.key, this.initialItem});

  bool get isEditMode => initialItem != null;

  @override
  ConsumerState<AddFormInventarisPage> createState() =>
      _AddFormInventarisPageState();
}

class _AddFormInventarisPageState extends ConsumerState<AddFormInventarisPage> {
  late TextEditingController _nameController;
  late TextEditingController _stockController;
  late TextEditingController _priceController;
  late TextEditingController _noteController;

  String? _selectedCategory;
  String? _selectedUnit;

  final List<String> _categories = [
    'Benih',
    'Pupuk',
    'Obat',
    'Peralatan',
    'Media Tanam',
  ];

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
    final item = widget.initialItem;

    _nameController = TextEditingController(text: item?.name ?? '');
    _stockController = TextEditingController(
      text: item != null ? item.stockValue.toInt().toString() : '',
    );
    _priceController = TextEditingController(
      text: item != null && item.price > 0 ? item.price.toStringAsFixed(0) : '',
    );
    _noteController = TextEditingController(text: item?.note ?? '');

    if (item?.category != null && _categories.contains(item!.category)) {
      _selectedCategory = item.category;
    }
    if (item?.stockUnit != null && _units.contains(item!.stockUnit)) {
      _selectedUnit = item.stockUnit;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _saveForm() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama barang tidak boleh kosong')),
      );
      return;
    }

    final viewModel = ref.read(inventarisViewModelProvider.notifier);
    final stockVal = double.tryParse(_stockController.text.trim()) ?? 0.0;
    final priceVal = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final unitVal = _selectedUnit ?? 'Pcs';

    StockStatus calcStatus = StockStatus.aman;
    if (stockVal <= 0) {
      calcStatus = StockStatus.habis;
    } else if (stockVal < 20) {
      calcStatus = StockStatus.menipis;
    }

    if (widget.isEditMode) {
      final updatedItem = widget.initialItem!.copyWith(
        name: _nameController.text.trim(),
        category: _selectedCategory ?? 'Umum',
        stockValue: stockVal,
        stockUnit: unitVal,
        mainUnit: '$unitVal ($unitVal)',
        price: priceVal,
        note: _noteController.text.trim(),
        status: calcStatus,
      );
      viewModel.updateItem(updatedItem);
    } else {
      final newItem = InventoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        category: _selectedCategory ?? 'Umum',
        stockValue: stockVal,
        stockUnit: unitVal,
        mainUnit: '$unitVal ($unitVal)',
        price: priceVal,
        note: _noteController.text.trim(),
        status: calcStatus,
      );
      viewModel.addItem(newItem);
    }

    Navigator.pop(context);
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
            ItemImagePlaceholder(
              imageUrl: widget.initialItem?.imageUrl,
              placeholderText: 'UNGGAH GAMBAR (OPSIONAL)',
              height: 120,
            ),
            const SizedBox(height: 20),
            _buildLabel('Nama Barang'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _nameController,
              hintText: 'Contoh: Pupuk AB Mix Selada',
            ),
            const SizedBox(height: 16),
            _buildLabel('Kategori'),
            const SizedBox(height: 6),
            _buildDropdownField<String>(
              value: _selectedCategory,
              hintText: 'Pilih kategori (Benih / Pupuk / Media)',
              items: _categories,
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(
                        widget.isEditMode ? 'Jumlah Stok' : 'Jumlah Awal',
                      ),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _stockController,
                        hintText: '0',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Satuan'),
                      const SizedBox(height: 6),
                      _buildDropdownField<String>(
                        value: _selectedUnit,
                        hintText: 'Kg / Butir / Pcs',
                        items: _units,
                        onChanged: (val) => setState(() => _selectedUnit = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLabel('Harga Pembelian (Rp)'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _priceController,
              hintText: 'Masukkan harga beli',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildLabel('Catatan Tambahan'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _noteController,
              hintText: 'Tulis lokasi penyimpanan atau merek',
              maxLines: 2,
            ),
            const SizedBox(height: 28),
            RowButton(
              label: widget.isEditMode ? 'Simpan Perubahan' : 'Simpan Barang',
              backgroundColor: const Color.fromRGBO(57, 198, 195, 1),
              textColor: Colors.white,
              borderRadius: 100.0,
              height: 52.0,
              onTap: _saveForm,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: Color.fromRGBO(24, 29, 39, 1),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color.fromRGBO(229, 231, 235, 1),
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
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
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required String hintText,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color.fromRGBO(229, 231, 235, 1),
          width: 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hintText,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color.fromRGBO(156, 163, 175, 1),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color.fromRGBO(156, 163, 175, 1),
          ),
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
