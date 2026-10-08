import 'package:flutter/material.dart';
import '../../models/weather_model.dart';
import '../theme/app_theme.dart';
import '../widgets/base_col_card.dart';
import '../widgets/capsule_badge.dart';
import '../widgets/card_icon_box.dart';
import '../widgets/row_info_card_md.dart';

class RekomendasiCuacaBody extends StatelessWidget {
  final PrakiraanHarian item;

  const RekomendasiCuacaBody({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.canvasWarm,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Card: Rekomendasi Berbasis Cuaca Apple HIG Banner
            RowInfoCardMd(
              backgroundColor: AppColors.accentMintSoft,
              borderColor: AppColors.borderAccent,
              padding: const EdgeInsets.all(AppSpacing.md),
              borderRadius: AppRadius.modal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CardIconBox(
                    iconData: Icons.cloud_outlined,
                    backgroundColor: AppColors.primaryMint,
                    iconColor: Colors.white,
                    width: 44,
                    height: 44,
                    borderRadius: 14,
                    iconSize: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rekomendasi Berbasis Cuaca',
                          style: AppTypography.headline.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          item.ringkasanSaran,
                          style: AppTypography.subheadline.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 2. Section Header
            Text(
              'TINDAKAN REKOMENDASI HARI INI',
              style: AppTypography.caption1.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDarkTeal,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 3. List Cards Rekomendasi
            ...item.rekomendasiList.map((rec) {
              final isPenting = rec.isPenting;
              final tagBgColor =
                  isPenting ? AppColors.warningBg : AppColors.accentMintSoft;
              final tagTextColor =
                  isPenting ? AppColors.warningOrange : AppColors.primaryDarkTeal;
              final tagBorderColor =
                  isPenting ? AppColors.warningOrange : AppColors.primaryMint;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: BaseColCard(
                  backgroundColor: Colors.white,
                  borderColor: AppColors.borderLight,
                  borderRadius: AppRadius.card,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              rec.judul,
                              style: AppTypography.headline.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          CapsuleBadge(
                            label: rec.labelTag,
                            textColor: tagTextColor,
                            backgroundColor: tagBgColor,
                            borderColor: tagBorderColor,
                            size: CapsuleSize.medium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        rec.deskripsi,
                        style: AppTypography.subheadline.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        rec.alasan,
                        style: AppTypography.caption1.copyWith(
                          color: AppColors.textTertiary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: AppSpacing.sm),

            // 4. Disclaimer Footer
            Text(
              'Disclaimer: Saran otomatis sistem berdasarkan analisis cuaca lokal & usia tanaman terkini. Modifikasi sesuai pengamatan visual lapangan petani.',
              style: AppTypography.caption2.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
