import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/table_record.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../pages/form_meja_nft_page.dart';
import '../pages/info_meja_page.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/filter_button.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/row_button.dart';
import '../widgets/capsule_badge.dart';
import '../widgets/fluid_capacity_meter.dart';

class MejaNftBody extends ConsumerWidget {
  const MejaNftBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectedTableProvider);
    final notifier = ref.read(connectedTableProvider.notifier);
    final counts = state.counts;
    final filteredList = state.filtered;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.canvasWarm,
      child: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomSearchBar(
                placeholder: 'Cari meja tanam...',
                onChanged: (value) => notifier.setSearchQuery(value),
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    FilterButton(
                      label: 'Semua (${counts['total']})',
                      isSelected: state.statusFilter == null,
                      onTap: () => notifier.setStatusFilter(null),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilterButton(
                      label: 'Aktif (${counts['aktif']})',
                      isSelected: state.statusFilter == 'tersedia',
                      onTap: () => notifier.setStatusFilter('tersedia'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilterButton(
                      label: 'Perawatan (${counts['perawatan']})',
                      isSelected: state.statusFilter == 'pemeliharaan',
                      onTap: () => notifier.setStatusFilter('pemeliharaan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: CircularProgressIndicator(
                      color: AppColors.primaryMint,
                    ),
                  ),
                )
              else if (filteredList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36.0),
                  child: Center(
                    child: Text(
                      state.error != null && state.records.isEmpty
                          ? 'Data meja tanam belum dapat dimuat.'
                          : state.records.isEmpty
                              ? 'Belum ada meja tanam terdaftar.'
                              : 'Meja tanam tidak ditemukan.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                )
              else
                ...filteredList.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: RowInfoCardMd(
                      backgroundColor: Colors.white,
                      borderColor: AppColors.borderLight,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InfoMejaPage(tableRecord: item),
                          ),
                        );
                      },
                      child: _ConnectedTableCardContent(item: item),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.xs),
              RowButton(
                label: '+ Tambah Meja NFT Baru',
                backgroundColor: AppColors.darkNavy,
                textColor: AppColors.accentLime,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FormMejaNftPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectedTableCardContent extends StatelessWidget {
  final TableRecord item;
  const _ConnectedTableCardContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final isMaintenance = item.isMaintenance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item.displayName,
              style: AppTypography.headline.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            CapsuleBadge(
              label: item.statusLabel,
              textColor: isMaintenance
                  ? AppColors.warningOrange
                  : AppColors.primaryDarkTeal,
              backgroundColor: isMaintenance
                  ? AppColors.warningBg
                  : AppColors.accentMintSoft,
              size: CapsuleSize.small,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (!isMaintenance) ...[
          FluidCapacityMeter(
            activePlants: item.activePlants,
            totalCapacity: item.holeCount,
            height: 6.0,
            showLabel: false,
            compact: true,
          ),
          const SizedBox(height: 6),
          Text(
            'Kapasitas: ${item.activePlants} / ${item.holeCount} Lubang Terisi (${item.occupancyPercentage}%)',
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.notes!,
              style: AppTypography.caption1.copyWith(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ] else ...[
          Text(
            'Dalam Perawatan / Pemeliharaan',
            style: AppTypography.caption1.copyWith(
              color: AppColors.warningOrange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
