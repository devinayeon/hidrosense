import 'package:flutter/material.dart';
import 'package:hidrosense_mobile/views/pages/add_form_inventaris_page.dart';
import '../components/header.dart';
import '../widgets/item_image_placeholder.dart';
import '../widgets/capsule_badge.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/stock_info_row.dart';
import '../widgets/stock_history_item.dart';
import '../widgets/col_button.dart';

class InfoItemInventarisPage extends StatelessWidget {
  final String itemName;
  final String category;
  final Color categoryColor;
  final Color categoryBgColor;
  final String? imageUrl;
  final String stockValue;
  final String stockUnit;
  final String mainUnit;

  // Callback aksi tombol
  final VoidCallback? onEditPressed;
  final VoidCallback? onDeactivatePressed;

  // Data Dummy Riwayat Perubahan Stok
  final List<Map<String, dynamic>> historyList;

  const InfoItemInventarisPage({
    super.key,
    this.itemName = 'Nama Barang',
    this.category = 'Benih',
    this.categoryColor = const Color.fromRGBO(57, 198, 195, 1),
    this.categoryBgColor = const Color.fromRGBO(237, 249, 248, 1),
    this.imageUrl,
    this.stockValue = '5.000',
    this.stockUnit = 'Butir',
    this.mainUnit = 'Butir (Btr)',
    this.onEditPressed,
    this.onDeactivatePressed,
    this.historyList = const [
      {
        'title': 'Pemakaian semai batch #04',
        'date': '01 Nov 2024',
        'amountText': '-400 btr',
        'isReduction': true,
      },
      {
        'title': 'Pembelian Baru - Toko Hidro',
        'date': '28 Okt 2024',
        'amountText': '+5.000 btr',
        'isReduction': false,
      },
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Header(titleText: 'Detail Barang', showBackButton: true),
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder Foto Barang
            ItemImagePlaceholder(imageUrl: imageUrl),

            const SizedBox(height: 16),

            // Nama Item
            Text(
              itemName,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                height: 1.0,
                letterSpacing: 0.0,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 10),

            // Badge Kategori
            CapsuleBadge(
              label: category,
              textColor: categoryColor,
              backgroundColor: categoryBgColor,
              size: CapsuleSize.medium,
            ),

            const SizedBox(height: 16),

            // Card Informasi Stok
            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(235, 238, 242, 1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: StockInfoRow(
                stockValue: stockValue,
                stockUnit: stockUnit,
                mainUnit: mainUnit,
              ),
            ),

            const SizedBox(height: 24),

            // Header Section Riwayat
            const Text(
              'RIWAYAT PERUBAHAN STOK',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color.fromRGBO(107, 114, 128, 1),
              ),
            ),

            const SizedBox(height: 12),

            // Card Daftar Riwayat Perubahan Stok
            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(235, 238, 242, 1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: List.generate(historyList.length, (index) {
                  final item = historyList[index];
                  final isLast = index == historyList.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: StockHistoryItem(
                          title: item['title'],
                          date: item['date'],
                          amountText: item['amountText'],
                          isReduction: item['isReduction'],
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 20,
                          thickness: 1,
                          color: Color.fromRGBO(243, 244, 246, 1),
                        ),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ColButton(
                    text: 'Edit Barang',
                    textColor: const Color.fromRGBO(57, 198, 195, 1),
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(57, 198, 195, 1),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddFormInventarisPage(
                            initialData: {
                              'name': itemName,
                              'category': category,
                              'stockValue': stockValue,
                              'stockUnit': stockUnit,
                              'imageUrl': imageUrl,
                              // sertakan harga/catatan jika ada
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ColButton(
                    text: 'Nonaktifkan',
                    textColor: const Color.fromRGBO(255, 140, 66, 1),
                    backgroundColor: const Color.fromRGBO(255, 248, 245, 1),
                    borderColor: const Color.fromRGBO(255, 140, 66, 1),
                    onPressed: onDeactivatePressed,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
