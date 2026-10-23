import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../models/penjualan_model.dart';
import '../theme/app_theme.dart';
import 'app_surface_colors.dart';
import 'capsule_badge.dart';

/// Kartu transaksi penjualan dengan permukaan, badge status, dan tipografi
/// yang sama seperti kartu inventaris.
class PenjualanCard extends StatelessWidget {
  final PenjualanItem item;
  final VoidCallback? onTap;

  const PenjualanCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);

    final statusText = item.isLunas ? 'LUNAS' : 'BELUM LUNAS';
    final badgeBg = item.isLunas
        ? colors.teal.withValues(alpha: 0.12)
        : colors.warning.withValues(alpha: 0.16);
    final badgeText = item.isLunas ? colors.teal : colors.warning;
    final badgeBorder = item.isLunas
        ? colors.teal.withValues(alpha: 0.35)
        : colors.warning.withValues(alpha: 0.35);

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
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CapsuleBadge(
                        label: statusText,
                        textColor: badgeText,
                        backgroundColor: badgeBg,
                        borderColor: badgeBorder,
                        size: CapsuleSize.small,
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
                  final identity = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.mintSurface,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                        ),
                        child: Icon(
                          Icons.storefront_outlined,
                          color: colors.teal,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.pembeli,
                              style: AppTypography.headline.copyWith(
                                color: colors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${item.tanggal} • ${item.kuantitas}',
                              style: AppTypography.caption1.copyWith(
                                color: colors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final amount = Text(
                    formatRupiah(item.totalHarga),
                    style: AppTypography.tabular(
                      AppTypography.title3.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                  final narrow =
                      constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.4;
                  return narrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            identity,
                            const SizedBox(height: AppSpacing.sm),
                            amount,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: identity),
                            const SizedBox(width: AppSpacing.sm),
                            amount,
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
