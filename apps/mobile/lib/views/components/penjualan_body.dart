import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/penjualan_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/catat_penjualan_page.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/penjualan_card.dart';
import '../widgets/row_button.dart';
import '../widgets/row_info_card_md.dart';

class PenjualanBody extends ConsumerWidget {
  const PenjualanBody({super.key});

  void _showFilterBottomSheet(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.read(penjualanFilterCategoryProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal),
            ),
          ),
          padding: EdgeInsets.only(
            top: 8,
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grabber Handle Apple HIG
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Status Penjualan',
                    style: AppTypography.title3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildFilterOption(
                context,
                ref,
                title: 'Semua Status',
                isSelected: activeFilter == PenjualanFilterCategory.all,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(penjualanFilterCategoryProvider.notifier).state =
                      PenjualanFilterCategory.all;
                  Navigator.pop(context);
                },
              ),
              _buildFilterOption(
                context,
                ref,
                title: 'Lunas',
                isSelected: activeFilter == PenjualanFilterCategory.lunas,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(penjualanFilterCategoryProvider.notifier).state =
                      PenjualanFilterCategory.lunas;
                  Navigator.pop(context);
                },
              ),
              _buildFilterOption(
                context,
                ref,
                title: 'Belum Lunas',
                isSelected: activeFilter == PenjualanFilterCategory.belumLunas,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(penjualanFilterCategoryProvider.notifier).state =
                      PenjualanFilterCategory.belumLunas;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      title: Text(
        title,
        style: AppTypography.body.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryMint)
          : null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(ref
            .watch(sessionProvider)
            .user
            ?.permissions
            .contains('penjualan:read') ??
        false)) {
      return const Center(child: Text('Akses penjualan tidak diizinkan.'));
    }
    final penjualanList = ref.watch(filteredPenjualanListProvider);
    final allCount = ref.watch(penjualanViewModelProvider).length;
    final totalPendapatan = ref.watch(totalPendapatanBulanIniProvider);

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.canvasWarm,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Card Total Pendapatan Bulan Ini Apple HIG Squircle
                  RowInfoCardMd(
                    backgroundColor: AppColors.primaryMint,
                    borderColor: AppColors.primaryMint,
                    borderRadius: AppRadius.modal,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total Pendapatan Bulan Ini',
                          style: AppTypography.subheadline.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          currencyFormatter.format(totalPendapatan),
                          style: AppTypography.title1.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Dari total $allCount transaksi penjualan terlaksana',
                          style: AppTypography.caption1.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Baris Search & Filter Button
                  Row(
                    children: [
                      Expanded(
                        child: CustomSearchBar(
                          placeholder: 'Cari pembeli...',
                          onChanged: (val) {
                            ref
                                    .read(penjualanSearchQueryProvider.notifier)
                                    .state =
                                val;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showFilterBottomSheet(context, ref);
                        },
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondarySurface,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Center(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.filter_list_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                Text(
                                  'Filter',
                                  style: AppTypography.caption1.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Daftar Card Penjualan
                  if (penjualanList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxxl,
                      ),
                      child: Center(
                        child: Text(
                          'Tidak ada data penjualan.',
                          style: AppTypography.subheadline.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: penjualanList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        return PenjualanCard(
                          item: penjualanList[index],
                          onTap: () {
                            HapticFeedback.lightImpact();
                            // Action detail transaksi penjualan
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // 4. Bottom Action Button: + Catat Penjualan Baru (Apple HIG 52pt pill button)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.canvasWarm,
            child: SafeArea(
              child: RowButton(
                label: '+ Catat Penjualan Baru',
                backgroundColor: AppColors.darkNavy,
                textColor: AppColors.accentLime,
                borderRadius: AppRadius.pill,
                height: 52,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CatatPenjualanPage(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
