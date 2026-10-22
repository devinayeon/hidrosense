import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/models/nursery_record.dart';
import '../theme/app_theme.dart';
import 'app_surface_colors.dart';
import 'capsule_badge.dart';
import 'feature_illustration.dart';

/// Kartu batch penyemaian dengan gaya yang sama seperti kartu inventaris:
/// badge status di atas, judul + ilustrasi, lalu metadata ringkas.
class SeedingBatchCard extends StatelessWidget {
  const SeedingBatchCard({
    super.key,
    required this.item,
    required this.canWrite,
    required this.onTap,
    required this.onTransfer,
  });

  final SowingRecord item;
  final bool canWrite;
  final VoidCallback onTap;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);
    final ready = item.canTransfer;
    final finished = item.status == 'selesai';

    final badgeBg = finished
        ? colors.secondary.withValues(alpha: 0.12)
        : ready
        ? colors.warning.withValues(alpha: 0.16)
        : colors.mintSurface;
    final badgeText = finished
        ? colors.secondary
        : ready
        ? colors.warning
        : colors.teal;
    final badgeBorder = finished
        ? colors.secondary.withValues(alpha: 0.3)
        : ready
        ? colors.warning.withValues(alpha: 0.35)
        : colors.teal.withValues(alpha: 0.35);

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
                        backgroundColor: badgeBg,
                        borderColor: badgeBorder,
                        size: CapsuleSize.medium,
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
                    item.batchName,
                    style: AppTypography.headline.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final art = FeatureIllustration(
                    asset: FeatureIllustration.nursery,
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
              if (ready && canWrite) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.teal,
                      minimumSize: const Size(44, 44),
                      side: BorderSide(color: colors.controlBorder),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                    ),
                    onPressed: onTransfer,
                    icon: Icon(
                      CupertinoIcons.arrow_right,
                      size: 15,
                      color: colors.teal,
                    ),
                    label: Text(
                      'Pindah ke Meja',
                      style: AppTypography.caption1.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Semaian: ${item.sowingDate}',
                style: AppTypography.caption1.copyWith(color: colors.secondary),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${item.seedCountText} • ${item.hssText}',
                style: AppTypography.tabular(
                  AppTypography.caption1.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.note != null && item.note!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.3),
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
                          item.note!,
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
