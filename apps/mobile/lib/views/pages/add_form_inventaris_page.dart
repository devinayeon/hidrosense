import 'package:flutter/material.dart';
import '../components/header.dart';
import '../widgets/item_image_placeholder.dart';
import '../widgets/row_button.dart';

class AddFormInventarisPage extends StatefulWidget {
  const AddFormInventarisPage({super.key});

  @override
  State<AddFormInventarisPage> createState() => _AddFormInventarisPageState();
}

class _AddFormInventarisPageState extends State<AddFormInventarisPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

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
    'Butir',
    'Pcs',
    'Blok',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Header(
        titleText: 'Tambah Barang Baru',
        showBackButton: true,
      ),
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder Foto Gambar (Opsional)
            const ItemImagePlaceholder(
              placeholderText: 'UNGGAH GAMBAR (OPSIONAL)',
              height: 120,
            ),

            const SizedBox(height: 20),

            // Field 1: Nama Barang
            _buildLabel('Nama Barang'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _nameController,
              hintText: 'Contoh: Pupuk AB Mix Selada',
            ),

            const SizedBox(height: 16),

            // Field 2: Kategori (Dropdown)
            _buildLabel('Kategori'),
            const SizedBox(height: 6),
            _buildDropdownField<String>(
              value: _selectedCategory,
              hintText: 'Pilih kategori (Benih / Pupuk / Media)',
              items: _categories,
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val;
                });
              },
            ),

            const SizedBox(height: 16),

            // Field 3: Jumlah Awal & Satuan (Side-by-side Row)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Jumlah Awal'),
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
                        onChanged: (val) {
                          setState(() {
                            _selectedUnit = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Field 4: Harga Pembelian (Rp)
            _buildLabel('Harga Pembelian (Rp)'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _priceController,
              hintText: 'Masukkan harga beli',
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            // Field 5: Catatan Tambahan
            _buildLabel('Catatan Tambahan'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _noteController,
              hintText: 'Tulis lokasi penyimpanan atau merek',
              maxLines: 2,
            ),

            const SizedBox(height: 28),

            // Tombol Simpan Barang (menggunakan RowButton)
            RowButton(
              label: 'Simpan Barang',
              backgroundColor: const Color.fromRGBO(57, 198, 195, 1),
              textColor: Colors.white,
              borderRadius: 100.0,
              height: 52.0,
              onTap: () {
                // Action Simpan Data Barang
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Helper Widget untuk Label Form
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

  // Helper Widget untuk Input Text Field
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

  // Helper Widget untuk Dropdown Field
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
