import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'capsule_badge.dart';

class StockInfoRow extends StatelessWidget {
  final String stockValue;
  final String stockUnit;
  final String mainUnit;
  final Color unitTextColor;
  final Color badgeBgColor;
  final Color badgeTextColor;

  const StockInfoRow({
    super.key,
    required this.stockValue,
    required this.stockUnit,
    required this.mainUnit,
    this.unitTextColor = AppColors.primaryMint,
    this.badgeBgColor = AppColors.accentLime,
    this.badgeTextColor = AppColors.darkNavy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Sisi Kiri: Stok Saat Ini
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stok Saat Ini',
              style: AppTypography.subheadline.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  stockValue,
                  style: AppTypography.title1.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  stockUnit,
                  style: AppTypography.callout.copyWith(
                    fontWeight: FontWeight.w600,
                    color: unitTextColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Sisi Kanan: Satuan Utama + CapsuleBadge
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Satuan Utama',
              style: AppTypography.subheadline.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            CapsuleBadge(
              label: mainUnit,
              textColor: badgeTextColor,
              backgroundColor: badgeBgColor,
              size: CapsuleSize.medium,
              fontWeight: FontWeight.w700,
            ),
          ],
        ),
      ],
    );
  }
}
