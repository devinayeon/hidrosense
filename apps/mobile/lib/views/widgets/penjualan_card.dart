import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/penjualan_model.dart';
import '../theme/app_theme.dart';
import 'capsule_badge.dart';

class PenjualanCard extends StatelessWidget {
  final PenjualanItem item;
  final VoidCallback? onTap;

  const PenjualanCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final String statusText = item.isLunas ? 'LUNAS' : 'BELUM LUNAS';
    final Color badgeBg =
        item.isLunas ? AppColors.accentMintSoft : AppColors.warningBg;
    final Color badgeText =
        item.isLunas ? AppColors.primaryDarkTeal : AppColors.warningOrange;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: AppColors.borderLight,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Info Pembeli & Tanggal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.pembeli,
                      style: AppTypography.subheadline.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${item.tanggal} • ${item.kuantitas}',
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Total Harga & Badge Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormatter.format(item.totalHarga),
                    style: AppTypography.subheadline.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  CapsuleBadge(
                    label: statusText,
                    textColor: badgeText,
                    backgroundColor: badgeBg,
                    borderColor: badgeText,
                    size: CapsuleSize.small,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
