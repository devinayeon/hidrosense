// lib/views/widgets/panen_card.dart
import 'package:flutter/material.dart';
import '../../models/panen_model.dart';
import '../theme/app_theme.dart';
import 'capsule_badge.dart';
import 'row_info_card_md.dart';

class PanenCard extends StatelessWidget {
  final PanenItem item;
  final VoidCallback? onTap;

  const PanenCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isEstimasi = item.isEstimasi;

    // Styling Badge berdasarkan status
    final String badgeLabel = isEstimasi ? 'Estimasi' : 'Selesai';
    final Color badgeBgColor =
        isEstimasi ? AppColors.accentMintSoft : AppColors.successBg;
    final Color badgeTextColor =
        isEstimasi ? AppColors.primaryDarkTeal : AppColors.successGreen;
    final Color badgeBorderColor =
        isEstimasi ? AppColors.primaryMint : AppColors.successGreen;

    // Dynamic subtitle (Meja info, HSS, Tanggal)
    final String subtitleText = item.targetHss != null
        ? '${item.mejaInfo} • ${item.targetHss} • ${item.dateText}'
        : '${item.mejaInfo} • ${item.dateText}';

    return RowInfoCardMd(
      backgroundColor: Colors.white,
      borderColor: AppColors.borderLight,
      borderRadius: AppRadius.card,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Atas: Judul Batch & Badge Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: AppTypography.subheadline.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              CapsuleBadge(
                label: badgeLabel,
                textColor: badgeTextColor,
                backgroundColor: badgeBgColor,
                borderColor: badgeBorderColor,
                size: CapsuleSize.medium,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),

          // Baris Tengah: Info Meja / HSS / Tanggal
          Text(
            subtitleText,
            style: AppTypography.caption1.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),

          // Baris Bawah: Detail Hasil / Estimasi
          Text(
            item.resultText,
            style: AppTypography.caption1.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
