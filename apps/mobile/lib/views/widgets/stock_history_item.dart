import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'capsule_badge.dart';

class StockHistoryItem extends StatelessWidget {
  final String title;
  final String date;
  final String amountText;
  final bool isReduction; // true jika berkurang (-), false jika bertambah (+)

  const StockHistoryItem({
    super.key,
    required this.title,
    required this.date,
    required this.amountText,
    this.isReduction = false,
  });

  @override
  Widget build(BuildContext context) {
    // Warna badge berdasarkan jenis perubahan (kurang/tambah)
    final Color badgeBgColor =
        isReduction ? AppColors.warningBg : AppColors.accentMintSoft;

    final Color badgeTextColor =
        isReduction ? AppColors.warningOrange : AppColors.primaryDarkTeal;

    final Color badgeBorderColor =
        isReduction ? AppColors.warningOrange : AppColors.primaryMint;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Sisi Kiri: Judul Aktivitas & Tanggal
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.subheadline.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                date,
                style: AppTypography.caption1.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Sisi Kanan: Capsule Badge Jumlah Stok
        CapsuleBadge(
          label: amountText,
          textColor: badgeTextColor,
          backgroundColor: badgeBgColor,
          borderColor: badgeBorderColor,
          size: CapsuleSize.medium,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}
