import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/weather_viewmodel.dart';
import '../pages/rekomendasi_cuaca_page.dart';
import '../theme/app_theme.dart';
import '../widgets/base_col_card.dart';
import '../widgets/capsule_badge.dart';

class CuacaBody extends ConsumerWidget {
  const CuacaBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherState = ref.watch(weatherViewModelProvider);

    if (weatherState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryMint,
        ),
      );
    }

    if (weatherState.errorMessage != null) {
      return Center(
        child: Text(
          weatherState.errorMessage!,
          style: AppTypography.body.copyWith(color: AppColors.dangerRed),
        ),
      );
    }

    final data = weatherState.data;
    if (data == null) return const SizedBox.shrink();

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
            // 1. Header Banner Lokasi Apple HIG Squircle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.lg,
                horizontal: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryMint,
                borderRadius: BorderRadius.circular(AppRadius.modal),
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.south_west_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        data.lokasi,
                        style: AppTypography.caption1.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    data.kota,
                    style: AppTypography.title1.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    data.sumber,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption2.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Grid 2x2 Info Cuaca Utama
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Suhu Udara',
                    value: '${data.suhu}°C',
                    badgeLabel: data.statusSuhu,
                    badgeBgColor: AppColors.accentMintSoft,
                    badgeTextColor: AppColors.primaryDarkTeal,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Kelembapan',
                    value: '${data.kelembapan}%',
                    badgeLabel: data.statusKelembapan,
                    badgeBgColor: AppColors.warningBg,
                    badgeTextColor: AppColors.warningOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Curah Hujan',
                    value: data.curahHujan,
                    subtitle: data.estimasiHujan,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Kecepatan Angin',
                    value: '${data.kecepatanAngin} Km/Jam',
                    subtitle: data.arahAngin,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 3. Section Prakiraan Harian Lokal (Bisa di-klik)
            Text(
              'PRAKIRAAN HARIAN LOKAL',
              style: AppTypography.caption1.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: AppColors.borderLight,
              borderRadius: AppRadius.card,
              padding: EdgeInsets.zero,
              child: Column(
                children: List.generate(data.prakiraanHarian.length, (index) {
                  final item = data.prakiraanHarian[index];
                  final isLast = index == data.prakiraanHarian.length - 1;

                  return Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.vertical(
                            top: index == 0
                                ? const Radius.circular(AppRadius.card)
                                : Radius.zero,
                            bottom: isLast
                                ? const Radius.circular(AppRadius.card)
                                : Radius.zero,
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RekomendasiCuacaPage(prakiraanItem: item),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.waktu,
                                  style: AppTypography.subheadline.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    CapsuleBadge(
                                      label: '${item.status} • ${item.suhu}°C',
                                      textColor: item.status.contains('Hujan')
                                          ? AppColors.primaryDarkTeal
                                          : AppColors.textPrimary,
                                      backgroundColor:
                                          item.status.contains('Hujan')
                                              ? AppColors.accentMintSoft
                                              : AppColors.secondarySurface,
                                      borderColor: item.status.contains('Hujan')
                                          ? AppColors.primaryMint
                                          : AppColors.borderLight,
                                      size: CapsuleSize.medium,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: AppColors.textTertiary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.borderSubtle,
                        ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Status Indicator API BMKG
            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: AppColors.borderLight,
              borderRadius: AppRadius.pill,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryMint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Data Diperbarui: ${data.lastUpdated}',
                      style: AppTypography.caption2.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget Card Metrik
  Widget _buildMetricCard({
    required String title,
    required String value,
    String? badgeLabel,
    Color? badgeBgColor,
    Color? badgeTextColor,
    String? subtitle,
  }) {
    return BaseColCard(
      backgroundColor: Colors.white,
      borderColor: AppColors.borderLight,
      borderRadius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(
            title,
            style: AppTypography.caption1.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppTypography.title2.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (badgeLabel != null)
            CapsuleBadge(
              label: badgeLabel,
              textColor: badgeTextColor ?? AppColors.textPrimary,
              backgroundColor: badgeBgColor ?? AppColors.secondarySurface,
              size: CapsuleSize.medium,
            ),
          if (subtitle != null)
            Text(
              subtitle,
              style: AppTypography.caption2.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}
