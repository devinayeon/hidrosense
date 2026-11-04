import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/models/inventory_record.dart';
import '../theme/app_theme.dart';
import 'inventory_colors.dart';
import 'inventory_illustration.dart';
import 'inventory_stock_label.dart';

/// Kartu item inventaris yang dapat ditekan untuk melihat detail.
/// Layout adaptif: ilustrasi di samping pada layar normal, di atas pada layar sempit.
class InventoryCard extends StatelessWidget {
  const InventoryCard({super.key, required this.item, required this.onTap});

  final InventoryRecord item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = InventoryColors.of(context);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        focusColor: colors.mintSurface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CategoryBadge(
                        category: item.category,
                        colors: colors,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: colors.secondary,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    item.name,
                    style: AppTypography.headline.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final art = InventoryIllustration(
                    asset: InventoryIllustration.forItem(item),
                    size: 72,
                  );
                  return constraints.maxWidth < 250 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.5
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [art, const SizedBox(height: 8), title],
                        )
                      : Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 12),
                            art,
                          ],
                        );
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    item.formattedStock,
                    style: AppTypography.tabular(
                      AppTypography.headline.copyWith(color: colors.ink),
                    ),
                  ),
                  InventoryStockLabel(item: item),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge kategori di pojok kiri atas kartu inventaris.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, required this.colors});

  final String category;
  final InventoryColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.mintSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Text(
        category,
        style: AppTypography.footnote.copyWith(
          color: colors.teal,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
