import 'package:flutter/material.dart';
import '../../core/formatting.dart';
import '../theme/app_theme.dart';

class EstimasiTotalCard extends StatelessWidget {
  final double totalAmount;

  const EstimasiTotalCard({super.key, required this.totalAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Estimasi Total (Otomatis)',
            style: AppTypography.subheadline.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            formatRupiah(totalAmount),
            style: AppTypography.headline.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
