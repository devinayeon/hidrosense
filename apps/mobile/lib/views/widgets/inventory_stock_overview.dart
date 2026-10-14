import 'package:flutter/material.dart';
import '../../data/models/inventory_record.dart';
import '../theme/app_theme.dart';
import 'inventory_colors.dart';
import 'inventory_illustration.dart';

/// Kartu ringkasan stok di bagian atas halaman inventaris.
/// Menampilkan total barang, jumlah kategori, dan barang yang perlu perhatian.
/// Layout adaptif: horizontal pada layar normal, vertikal pada layar sempit.
class InventoryStockOverview extends StatelessWidget {
  const InventoryStockOverview({
    super.key,
    required this.items,
    required this.categories,
    required this.loading,
  });

  final List<InventoryRecord> items;
  final int categories;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = InventoryColors.of(context);
    final attention = items
        .where((item) => item.isLow || item.isOutOfStock)
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.mintSurface,
        borderRadius: BorderRadius.circular(AppRadius.modal),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Persediaan\nkebunmu',
                style: AppTypography.title2.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loading
                    ? 'Memuat persediaan...'
                    : '${items.length} barang · $categories kategori',
                style: AppTypography.subheadline.copyWith(
                  color: colors.secondary,
                ),
              ),
              if (!loading && attention > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$attention barang perlu perhatian',
                    style: AppTypography.footnote.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          );
          final art = TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) => Opacity(opacity: value, child: child),
            child: const InventoryIllustration(
              asset: InventoryIllustration.overview,
              size: 112,
            ),
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [art, const SizedBox(height: 12), text],
                )
              : Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: 8),
                    art,
                  ],
                );
        },
      ),
    );
  }
}
