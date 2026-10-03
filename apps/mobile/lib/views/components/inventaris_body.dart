import 'package:flutter/material.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/filter_button.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/card_icon_box.dart';
import '../widgets/stock_status_badge.dart';
import '../widgets/item_info_details.dart';
import '../widgets/row_button.dart';

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
            const CustomSearchBar(
              placeholder: 'Cari nama barang...',
            ),

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

            // Item 1: Benih Selada Grand Rapids
            RowInfoCardMd(
              backgroundColor: const Color.fromRGBO(255, 255, 255, 1),
              borderColor: const Color.fromRGBO(229, 231, 235, 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  CardIconBox(
                    iconData: Icons.inventory_2_outlined,
                    backgroundColor: Color.fromRGBO(237, 249, 248, 1),
                    iconColor: Color.fromRGBO(57, 198, 195, 1),
                    width: 44,
                    height: 44,
                    borderRadius: 14,
                    iconSize: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ItemInfoDetails(
                      name: 'Benih Selada Grand Rapids',
                      category: 'Benih',
                      stockText: '5.000 btr',
                      categoryColor: Color.fromRGBO(57, 198, 195, 1),
                      categoryBgColor: Color.fromRGBO(237, 249, 248, 1),
                    ),
                  ),
                  SizedBox(width: 8),
                  StockStatusBadge(status: StockStatus.aman),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Item 2: Pupuk AB Mix Selada
            RowInfoCardMd(
              backgroundColor: const Color.fromRGBO(255, 255, 255, 1),
              borderColor: const Color.fromRGBO(255, 237, 224, 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  CardIconBox(
                    iconData: Icons.inventory_2_outlined,
                    backgroundColor: Color.fromRGBO(255, 243, 236, 1),
                    iconColor: Color.fromRGBO(255, 154, 85, 1),
                    width: 44,
                    height: 44,
                    borderRadius: 14,
                    iconSize: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ItemInfoDetails(
                      name: 'Pupuk AB Mix Selada',
                      category: 'Pupuk',
                      stockText: '45 Kg',
                      categoryColor: Color.fromRGBO(255, 154, 85, 1),
                      categoryBgColor: Color.fromRGBO(255, 243, 236, 1),
                    ),
                  ),
                  SizedBox(width: 8),
                  StockStatusBadge(status: StockStatus.menipis),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Item 3: Rockwool Media Tanam
            RowInfoCardMd(
              backgroundColor: const Color.fromRGBO(255, 255, 255, 1),
              borderColor: const Color.fromRGBO(229, 231, 235, 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  CardIconBox(
                    iconData: Icons.inventory_2_outlined,
                    backgroundColor: Color.fromRGBO(245, 252, 210, 1),
                    iconColor: Color.fromRGBO(140, 198, 35, 1),
                    width: 44,
                    height: 44,
                    borderRadius: 14,
                    iconSize: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ItemInfoDetails(
                      name: 'Rockwool Media Tanam',
                      category: 'Media Tanam',
                      stockText: '12 Blok',
                      categoryColor: Color.fromRGBO(120, 175, 20, 1),
                      categoryBgColor: Color.fromRGBO(245, 252, 210, 1),
                    ),
                  ),
                  SizedBox(width: 8),
                  StockStatusBadge(status: StockStatus.aman),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tombol di bagian bawah
            RowButton(
              label: '+ Tambah Barang Baru',
              onTap: () {
                // Aksi saat tombol diklik
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}