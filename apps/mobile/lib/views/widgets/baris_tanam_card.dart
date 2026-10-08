// lib/views/widgets/baris_tanam_card.dart
import 'package:flutter/material.dart';
import '../../models/baris_tanam_model.dart';
import '../theme/app_theme.dart';
import 'capsule_badge.dart';
import 'row_info_card_md.dart';

class BarisTanamCard extends StatelessWidget {
  final BarisTanam item;

  const BarisTanamCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final bool isPerfect = item.isPerfect;

    // Skema warna berdasarkan kondisi
    final Color borderColor = isPerfect
        ? AppColors.borderSubtle
        : AppColors.warningOrange.withOpacity(0.3);
    final Color badgeBgColor = isPerfect
        ? AppColors.accentMintSoft
        : AppColors.warningBg;
    final Color badgeTextColor = isPerfect
        ? AppColors.primaryMint
        : AppColors.warningOrange;
    final Color badgeBorderColor = isPerfect
        ? AppColors.borderAccent
        : AppColors.warningOrange.withOpacity(0.4);

    final String statusBadgeText = isPerfect
        ? '100% Ok'
        : '${item.failedCount} Rusak';

    return RowInfoCardMd(
      backgroundColor: AppColors.cardSurface,
      borderColor: borderColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sisi Kiri: Judul & Informasi Detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.name} (${item.holesRange})',
                  style: AppTypography.headline.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkNavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (isPerfect) ...[
                      CapsuleBadge(
                        label: '${item.totalBibit} Bibit',
                        textColor: AppColors.primaryMint,
                        backgroundColor: AppColors.accentMintSoft,
                        size: CapsuleSize.small,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '•  Sehat • Usia ${item.hss} HSS',
                        style: AppTypography.caption1.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ] else ...[
                      CapsuleBadge(
                        label: '${item.healthyCount} Sehat',
                        textColor: AppColors.warningOrange,
                        backgroundColor: AppColors.warningBg,
                        size: CapsuleSize.small,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '•  ${item.failedCount} Gagal Tumbuh / Busuk',
                        style: AppTypography.caption1.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Sisi Kanan: Badge Indikator Status Persentase / Rusak
          CapsuleBadge(
            label: statusBadgeText,
            textColor: badgeTextColor,
            backgroundColor: badgeBgColor,
            borderColor: badgeBorderColor,
            size: CapsuleSize.medium,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}
