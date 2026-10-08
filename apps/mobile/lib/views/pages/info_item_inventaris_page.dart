import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_item_model.dart';
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../../viewmodels/inventaris_viewmodel.dart';
import 'add_form_inventaris_page.dart';
import '../components/header.dart';
import '../theme/app_theme.dart';
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
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx);
            },
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
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
      backgroundColor: AppColors.canvasWarm,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemImagePlaceholder(imageUrl: currentItem.imageUrl),
            const SizedBox(height: AppSpacing.md),
            Text(
              currentItem.name,
              style: AppTypography.title2.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            CapsuleBadge(
              label: currentItem.category,
              textColor: AppColors.primaryMint,
              backgroundColor: AppColors.accentMintSoft,
              borderColor: AppColors.primaryMint,
              size: CapsuleSize.medium,
            ),
            const SizedBox(height: AppSpacing.md),
            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: AppColors.borderLight,
              borderRadius: AppRadius.card,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              child: StockInfoRow(
                stockValue: currentItem.formattedStock,
                stockUnit: currentItem.stockUnit,
                mainUnit: currentItem.mainUnit,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'RIWAYAT PERUBAHAN STOK',
              style: AppTypography.caption1.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: AppColors.borderLight,
              borderRadius: AppRadius.card,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
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
                          color: AppColors.borderSubtle,
                        ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: ColButton(
                    text: 'Edit Barang',
                    textColor: AppColors.primaryMint,
                    backgroundColor: Colors.white,
                    borderColor: AppColors.primaryMint,
                    height: 52,
                    borderRadius: AppRadius.pill,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final matchingRecords = ref
                          .read(connectedInventoryProvider)
                          .records
                          .where((record) => record.id == currentItem.id);
                      if (matchingRecords.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Data inventaris belum tersedia untuk diedit.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddFormInventarisPage(
                            initialRecord: matchingRecords.first,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ColButton(
                    text: 'Nonaktifkan',
                    textColor: AppColors.warningOrange,
                    backgroundColor: AppColors.warningBg,
                    borderColor: AppColors.warningOrange,
                    height: 52,
                    borderRadius: AppRadius.pill,
                    onPressed: () => _showDeactivateDialog(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
