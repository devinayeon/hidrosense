import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/inventory_record.dart';
import '../../models/inventory_item_model.dart' show StockStatus;
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/filter_button.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/card_icon_box.dart';
import '../widgets/stock_status_badge.dart';
import '../widgets/item_info_details.dart';
import '../widgets/row_button.dart';
import '../pages/add_form_inventaris_page.dart';

class InventarisBody extends ConsumerStatefulWidget {
  const InventarisBody({super.key});

  @override
  ConsumerState<InventarisBody> createState() => _InventarisBodyState();
}

class _InventarisBodyState extends ConsumerState<InventarisBody> {
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  void _showDetail(InventoryRecord item) {
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: Text(
          item.name,
          style: AppTypography.title3.copyWith(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Jenis: ${item.category}',
                style: AppTypography.subheadline.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Saldo: ${item.formattedStock}',
                style: AppTypography.headline.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.minimum == null
                    ? 'Stok minimum belum ditetapkan.'
                    : 'Stok minimum: ${item.minimum} ${item.unit}',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _stockLabel(item),
                style: AppTypography.subheadline.copyWith(
                  color: item.isLow ? AppColors.warningOrange : AppColors.primaryDarkTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: AppTypography.body.copyWith(
                color: AppColors.primaryDarkTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stockLabel(InventoryRecord item) {
    if (item.isOutOfStock) return 'Stok habis';
    if (item.isLow) return 'Di bawah stok minimum';
    return item.minimum == null ? 'Stok tersedia' : 'Stok mencukupi';
  }

  StockStatus _statusFor(InventoryRecord item) {
    if (item.isOutOfStock) return StockStatus.habis;
    if (item.isLow) return StockStatus.menipis;
    return StockStatus.aman;
  }

  ({IconData icon, Color bgColor, Color iconColor}) _categoryIconStyle(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('benih')) {
      return (
        icon: Icons.eco_rounded,
        bgColor: AppColors.accentMintSoft,
        iconColor: AppColors.primaryMint,
      );
    } else if (cat.contains('nutrisi') || cat.contains('pupuk')) {
      return (
        icon: Icons.water_drop_rounded,
        bgColor: AppColors.infoBg,
        iconColor: AppColors.infoBlue,
      );
    } else if (cat.contains('obat') || cat.contains('pestisida')) {
      return (
        icon: Icons.shield_rounded,
        bgColor: AppColors.warningBg,
        iconColor: AppColors.warningOrange,
      );
    } else {
      return (
        icon: Icons.grid_view_rounded,
        bgColor: AppColors.secondarySurface,
        iconColor: AppColors.darkNavy,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectedInventoryProvider);
    final refresh = ref.read(connectedInventoryProvider.notifier).refresh;

    final activeItems = state.records.where((i) => i.active).toList();
    final dynamicCategories = <String>{'Semua', ...activeItems.map((i) => i.category)}.toList();

    final filtered = activeItems.where((item) {
      final matchCat = _selectedCategory == 'Semua' || item.category == _selectedCategory;
      final matchQuery = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchQuery;
    }).toList();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.canvasWarm,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.cached)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(color: AppColors.warningOrange.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.offline_pin_outlined, size: 18, color: AppColors.warningOrange),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'Menampilkan salinan lokal. Saldo mungkin sudah berubah.',
                                style: AppTypography.caption1.copyWith(color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (state.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(color: AppColors.dangerRed.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 18, color: AppColors.dangerRed),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: AppTypography.caption1.copyWith(color: AppColors.dangerRed),
                              ),
                            ),
                          ],
                        ),
                      ),
                    CustomSearchBar(
                      placeholder: 'Cari nama barang...',
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: dynamicCategories.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: FilterButton(
                              label: cat,
                              isSelected: _selectedCategory == cat,
                              onTap: () => setState(() => _selectedCategory = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (state.loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: CircularProgressIndicator(color: AppColors.primaryMint),
                        ),
                      )
                    else if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            state.error != null && activeItems.isEmpty
                                ? 'Data inventaris belum dapat ditampilkan.'
                                : activeItems.isEmpty
                                ? 'Belum ada barang inventaris aktif.'
                                : 'Tidak ada barang yang cocok.',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...filtered.map((item) {
                        final iconStyle = _categoryIconStyle(item.category);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: RowInfoCardMd(
                            backgroundColor: Colors.white,
                            borderColor: AppColors.borderLight,
                            onTap: () => _showDetail(item),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CardIconBox(
                                  iconData: iconStyle.icon,
                                  backgroundColor: iconStyle.bgColor,
                                  iconColor: iconStyle.iconColor,
                                  width: 44,
                                  height: 44,
                                  borderRadius: 14,
                                  iconSize: 22,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: ItemInfoDetails(
                                    name: item.name,
                                    category: item.category,
                                    stockText: item.formattedStock,
                                    categoryColor: AppColors.primaryDarkTeal,
                                    categoryBgColor: AppColors.accentMintSoft,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                StockStatusBadge(status: _statusFor(item)),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),

          // Sticky Bottom Action Container (Apple HIG 52pt pill button)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.canvasWarm,
              border: Border(
                top: BorderSide(
                  color: AppColors.borderSubtle,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: RowButton(
                label: '+ Tambah Barang Baru',
                backgroundColor: AppColors.primaryMint,
                textColor: Colors.white,
                borderRadius: AppRadius.pill,
                height: 52,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddFormInventarisPage(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
