import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'capsule_badge.dart';

class SeedingCardContent extends StatelessWidget {
  final String batchName;
  final String statusLabel;
  final Color statusTextColor;
  final Color statusBgColor;
  final Color statusBorderColor;
  final String? variety;
  final String dateText;
  final String seedCountText;
  final String hssText;
  final String? note;

  const SeedingCardContent({
    super.key,
    required this.batchName,
    required this.statusLabel,
    required this.statusTextColor,
    required this.statusBgColor,
    required this.statusBorderColor,
    this.variety,
    required this.dateText,
    required this.seedCountText,
    required this.hssText,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris Atas: Judul Batch dan Badge Status
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              batchName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headline.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            CapsuleBadge(
              label: statusLabel,
              textColor: statusTextColor,
              backgroundColor: statusBgColor,
              borderColor: statusBorderColor,
              size: CapsuleSize.medium,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xs),

        // Subtitle Varietas
        if (variety != null)
          Text(
            'Varietas: $variety',
            style: AppTypography.subheadline.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),

        const SizedBox(height: AppSpacing.xxs),

        // Info Semaian & HSS (Tanggal + Jumlah Bibit • X HSS)
        RichText(
          textScaler: MediaQuery.textScalerOf(context),
          text: TextSpan(
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary,
            ),
            children: [
              TextSpan(text: 'Semaian: $dateText '),
              TextSpan(
                text: '$seedCountText • $hssText',
                style: AppTypography.caption1.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        // Box Catatan/Rekomendasi (Jika ada)
        if (note != null && note!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: AppColors.warningOrange.withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.warningOrange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    note!,
                    style: AppTypography.caption1.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
