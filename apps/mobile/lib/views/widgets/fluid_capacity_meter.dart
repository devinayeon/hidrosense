import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Meter kapasitas lubang meja tanam NFT dengan animasi pengisian fluida
/// (Fluid Filling Animation) berbasis Apple HIG (450ms, easeOutCubic).
class FluidCapacityMeter extends StatelessWidget {
  final int activePlants;
  final int totalCapacity;
  final double height;
  final bool showLabel;
  final bool compact;

  const FluidCapacityMeter({
    super.key,
    required this.activePlants,
    required this.totalCapacity,
    this.height = 10.0,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double safeCapacity = totalCapacity > 0
        ? totalCapacity.toDouble()
        : 1.0;
    final double ratio = (activePlants / safeCapacity).clamp(0.0, 1.0);
    final int percent = (ratio * 100).round();

    // Palet warna fluida adaptif sesuai okupansi
    final List<Color> fluidGradient = ratio >= 0.95
        ? const [AppColors.warningOrange, AppColors.dangerRed]
        : ratio >= 0.8
        ? const [AppColors.accentLime, AppColors.primaryMint]
        : const [AppColors.primaryMint, AppColors.primaryDarkTeal];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Okupansi Meja NFT',
                style: AppTypography.caption1.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$activePlants / $totalCapacity Lubang ($percent%)',
                style: AppTypography.tabular(
                  AppTypography.caption1.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ratio >= 0.95
                        ? AppColors.dangerRed
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // Container Track Fluida
        Container(
          key: const ValueKey('fluid-capacity-track'),
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.secondarySurface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.borderSubtle, width: 1.0),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = constraints.maxWidth;
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: ratio),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, animatedRatio, _) {
                  final double fillWidth = (maxWidth * animatedRatio).clamp(
                    0.0,
                    maxWidth,
                  );
                  return Stack(
                    children: [
                      // Batang Pengisian Fluida
                      Container(
                        key: const ValueKey('fluid-capacity-fill'),
                        width: fillWidth,
                        height: height,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: fluidGradient,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: animatedRatio > 0.05
                              ? [
                                  BoxShadow(
                                    color: fluidGradient.first.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      // Efek kilau permukaan cairan (fluid meniscus highlight)
                      if (animatedRatio > 0.1 && !compact)
                        Positioned(
                          top: 1,
                          left: 2,
                          width: (fillWidth - 4).clamp(0.0, maxWidth),
                          height: (height * 0.35).clamp(1.0, height),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
