import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_item_model.dart';
import '../../viewmodels/inventaris_viewmodel.dart';
import 'add_form_inventaris_page.dart';
import '../components/header.dart';
import '../widgets/item_image_placeholder.dart';
import '../widgets/capsule_badge.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/stock_info_row.dart';
import '../widgets/stock_history_item.dart';
import '../widgets/col_button.dart';

class InfoItemInventarisPage extends ConsumerWidget {
  final InventoryItem item;

  final List<Map<String, dynamic>> historyList;

  const InfoItemInventarisPage({
    super.key,
    required this.item,
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

  void _showDeactivateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Barang'),
        content: Text(
          'Apakah Anda yakin ingin menonaktifkan "${item.name}"? Barang ini tidak akan muncul di daftar aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(inventarisViewModelProvider.notifier)
                  .softDeleteItem(item.id);
              Navigator.pop(ctx); // Tutup Dialog
              Navigator.pop(context); // Kembali ke halaman utama
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${item.name} telah dinonaktifkan')),
              );
            },
            child: const Text(
              'Nonaktifkan',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Membaca versi item terbaru dari state
    final stateItems = ref.watch(inventarisViewModelProvider).items;
    final currentItem = stateItems.firstWhere(
      (i) => i.id == item.id,
      orElse: () => item,
    );

    return Scaffold(
      appBar: const Header(titleText: 'Detail Barang', showBackButton: true),
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemImagePlaceholder(imageUrl: currentItem.imageUrl),
            const SizedBox(height: 16),
            Text(
              currentItem.name,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                height: 1.0,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            CapsuleBadge(
              label: currentItem.category,
              textColor: const Color.fromRGBO(57, 198, 195, 1),
              backgroundColor: const Color.fromRGBO(237, 249, 248, 1),
              size: CapsuleSize.medium,
            ),
            const SizedBox(height: 16),
            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(235, 238, 242, 1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: StockInfoRow(
                stockValue: currentItem.formattedStock,
                stockUnit: currentItem.stockUnit,
                mainUnit: currentItem.mainUnit,
              ),
            ),
            const SizedBox(height: 24),
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
            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(235, 238, 242, 1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: List.generate(historyList.length, (index) {
                  final hItem = historyList[index];
                  final isLast = index == historyList.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: StockHistoryItem(
                          title: hItem['title'],
                          date: hItem['date'],
                          amountText: hItem['amountText'],
                          isReduction: hItem['isReduction'],
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
                          builder: (context) =>
                              AddFormInventarisPage(initialItem: currentItem),
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
                    onPressed: () => _showDeactivateDialog(context, ref),
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
