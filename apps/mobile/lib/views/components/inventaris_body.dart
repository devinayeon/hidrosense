import 'package:flutter/material.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/filter_button.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/card_icon_box.dart';
import '../widgets/stock_status_badge.dart';
import '../widgets/item_info_details.dart';
import '../widgets/row_button.dart';
import '../pages/info_item_inventaris_page.dart';
import '../pages/add_form_inventaris_page.dart'; // Import page baru

class InventarisBody extends StatefulWidget {
  const InventarisBody({super.key});

  @override
  State<InventarisBody> createState() => _InventarisBodyState();
}

class _InventarisBodyState extends State<InventarisBody> {
  int _selectedFilterIndex = 0;

  final List<String> _categories = [
    'Semua',
    'Benih',
    'Pupuk',
    'Obat',
    'Peralatan',
    'Media Tanam',
  ];

  // Data List Item disimpan dalam bentuk List of Map
  final List<Map<String, dynamic>> _inventoryItems = [
    {
      'name': 'Benih Selada Grand Rapids',
      'category': 'Benih',
      'stockText': '5.000 btr',
      'categoryColor': const Color.fromRGBO(57, 198, 195, 1),
      'categoryBgColor': const Color.fromRGBO(237, 249, 248, 1),
      'iconBgColor': const Color.fromRGBO(237, 249, 248, 1),
      'iconColor': const Color.fromRGBO(57, 198, 195, 1),
      'borderColor': const Color.fromRGBO(229, 231, 235, 1),
      'status': StockStatus.aman,
    },
    {
      'name': 'Pupuk AB Mix Selada',
      'category': 'Pupuk',
      'stockText': '45 Kg',
      'categoryColor': const Color.fromRGBO(255, 154, 85, 1),
      'categoryBgColor': const Color.fromRGBO(255, 243, 236, 1),
      'iconBgColor': const Color.fromRGBO(255, 243, 236, 1),
      'iconColor': const Color.fromRGBO(255, 154, 85, 1),
      'borderColor': const Color.fromRGBO(255, 237, 224, 1),
      'status': StockStatus.menipis,
    },
    {
      'name': 'Rockwool Media Tanam',
      'category': 'Media Tanam',
      'stockText': '12 Blok',
      'categoryColor': const Color.fromRGBO(120, 175, 20, 1),
      'categoryBgColor': const Color.fromRGBO(245, 252, 210, 1),
      'iconBgColor': const Color.fromRGBO(245, 252, 210, 1),
      'iconColor': const Color.fromRGBO(140, 198, 35, 1),
      'borderColor': const Color.fromRGBO(229, 231, 235, 1),
      'status': StockStatus.aman,
    },
  ];

  void _navigateToDetail(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfoItemInventarisPage(itemName: name),
      ),
    );
  }

  void _navigateToAddForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFormInventarisPage()),
    );
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
            // Baris Pertama: Search Bar
            const CustomSearchBar(placeholder: 'Cari nama barang...'),

            const SizedBox(height: 16),

            // Baris Kedua: Horizontal Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(_categories.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: FilterButton(
                      label: _categories[index],
                      isSelected: _selectedFilterIndex == index,
                      onTap: () {
                        setState(() {
                          _selectedFilterIndex = index;
                        });
                      },
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            // Perulangan untuk Menampilkan List Item Inventaris
            ..._inventoryItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: RowInfoCardMd(
                  backgroundColor: Colors.white,
                  borderColor: item['borderColor'],
                  onTap: () => _navigateToDetail(item['name']),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CardIconBox(
                        iconData: Icons.inventory_2_outlined,
                        backgroundColor: item['iconBgColor'],
                        iconColor: item['iconColor'],
                        width: 44,
                        height: 44,
                        borderRadius: 14,
                        iconSize: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ItemInfoDetails(
                          name: item['name'],
                          category: item['category'],
                          stockText: item['stockText'],
                          categoryColor: item['categoryColor'],
                          categoryBgColor: item['categoryBgColor'],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StockStatusBadge(status: item['status']),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // Tombol Tambah Barang
            RowButton(label: '+ Tambah Barang Baru', onTap: _navigateToAddForm),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
