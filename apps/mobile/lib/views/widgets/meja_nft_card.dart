import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/models/table_record.dart';
import '../theme/app_theme.dart';
import 'app_surface_colors.dart';
import 'capsule_badge.dart';
import 'feature_illustration.dart';

/// Kartu meja tanam dengan gaya yang sama seperti kartu inventaris,
/// penyemaian, dan penjualan: permukaan, badge status, ilustrasi fitur,
/// ringkasan kapasitas, dan catatan opsional.
class MejaNftCard extends StatelessWidget {
  const MejaNftCard({super.key, required this.item, required this.onTap});

  final TableRecord item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);
    final maintenance = item.isMaintenance;
    final full = item.isFull;
    final available = item.isAvailable;

    final badgeBackground = maintenance
        ? colors.warning.withValues(alpha: 0.16)
        : full
        ? colors.warning.withValues(alpha: 0.16)
        : available
        ? colors.teal.withValues(alpha: 0.12)
        : colors.secondary.withValues(alpha: 0.12);
    final badgeText = maintenance || full
        ? colors.warning
        : available
        ? colors.teal
        : colors.secondary;
    final badgeBorder = maintenance || full
        ? colors.warning.withValues(alpha: 0.35)
        : available
        ? colors.teal.withValues(alpha: 0.35)
        : colors.secondary.withValues(alpha: 0.3);

    final capacityColor = maintenance || item.occupancyRatio >= 0.9
        ? colors.warning
        : colors.teal;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        focusColor: colors.mintSurface,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CapsuleBadge(
                        label: item.statusLabel,
                        textColor: badgeText,
                        backgroundColor: badgeBackground,
                        borderColor: badgeBorder,
                        size: CapsuleSize.medium,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: colors.secondary,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    item.displayName,
                    style: AppTypography.headline.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final art = FeatureIllustration(
                    asset: FeatureIllustration.table,
                    size: 64,
                  );
                  return constraints.maxWidth < 250 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.5
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            art,
                            const SizedBox(height: AppSpacing.xs),
                            title,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: AppSpacing.sm),
                            art,
                          ],
                        );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${item.activePlants} / ${item.holeCount} lubang terisi',
                    style: AppTypography.tabular(
                      AppTypography.subheadline.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${item.occupancyPercentage}%',
                    style: AppTypography.tabular(
                      AppTypography.caption1.copyWith(
                        color: colors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _CapacityBar(
                ratio: item.occupancyRatio,
                color: capacityColor,
                trackColor: colors.mintSurface,
              ),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          item.notes!,
                          style: AppTypography.caption1.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CapacityBar extends StatelessWidget {
  const _CapacityBar({
    required this.ratio,
    required this.color,
    required this.trackColor,
  });

  final double ratio;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final value = ratio.clamp(0.0, 1.0);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);

    return Semantics(
      label: 'Kapasitas terisi ${(value * 100).round()} persen',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 8,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: trackColor),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: duration,
                curve: Curves.easeOutCubic,
                builder: (_, animated, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animated,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
