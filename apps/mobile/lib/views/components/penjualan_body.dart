import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../viewmodels/penjualan_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/catat_penjualan_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_surface_colors.dart';
import '../widgets/feature_illustration.dart';
import '../widgets/feature_overview_card.dart';
import '../widgets/penjualan_card.dart';
import '../widgets/row_button.dart';
import '../widgets/surface_empty_state.dart';
import '../widgets/surface_search_field.dart';
import '../widgets/surface_section_header.dart';

class PenjualanBody extends ConsumerStatefulWidget {
  const PenjualanBody({super.key});

  @override
  ConsumerState<PenjualanBody> createState() => _PenjualanBodyState();
}

class _PenjualanBodyState extends ConsumerState<PenjualanBody> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    ref.read(penjualanSearchQueryProvider.notifier).state = '';
    ref.read(penjualanFilterCategoryProvider.notifier).state =
        PenjualanFilterCategory.all;
  }

  void _showFilterBottomSheet() {
    final activeFilter = ref.read(penjualanFilterCategoryProvider);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = AppSurfaceColors.of(sheetContext);

        Widget option({
          required String title,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.body.copyWith(
                        color: selected ? colors.ink : colors.secondary,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: colors.teal,
                      size: 22,
                    ),
                ],
              ),
            ),
          );
        }

        void select(PenjualanFilterCategory category) {
          HapticFeedback.selectionClick();
          ref.read(penjualanFilterCategoryProvider.notifier).state = category;
          Navigator.pop(sheetContext);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Status Penjualan',
                style: AppTypography.title3.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              option(
                title: 'Semua Status',
                selected: activeFilter == PenjualanFilterCategory.all,
                onTap: () => select(PenjualanFilterCategory.all),
              ),
              option(
                title: 'Lunas',
                selected: activeFilter == PenjualanFilterCategory.lunas,
                onTap: () => select(PenjualanFilterCategory.lunas),
              ),
              option(
                title: 'Belum Lunas',
                selected: activeFilter == PenjualanFilterCategory.belumLunas,
                onTap: () => select(PenjualanFilterCategory.belumLunas),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRead =
        ref
            .watch(sessionProvider)
            .user
            ?.permissions
            .contains('penjualan:read') ??
        false;
    if (!canRead) {
      return const Center(child: Text('Akses penjualan tidak diizinkan.'));
    }

    final penjualanList = ref.watch(filteredPenjualanListProvider);
    final state = ref.watch(penjualanViewModelProvider);
    final allItems = state.items;
    final totalPendapatan = ref.watch(totalPendapatanBulanIniProvider);
    final query = ref.watch(penjualanSearchQueryProvider);
    final filter = ref.watch(penjualanFilterCategoryProvider);
    final colors = AppSurfaceColors.of(context);

    if (state.isInitialLoading) {
      return ColoredBox(
        color: colors.canvas,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null && !state.salesLoaded) {
      return ColoredBox(
        color: colors.canvas,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SurfaceEmptyState(
              illustration: FeatureIllustration.noResults,
              title: 'Gagal memuat penjualan.',
              message: state.error!,
              actionLabel: 'Coba lagi',
              onAction: () =>
                  ref.read(penjualanViewModelProvider.notifier).refresh(),
            ),
          ),
        ),
      );
    }

    final allCount = allItems.length;
    final paidCount = allItems.where((item) => item.isLunas).length;
    final hasFilter =
        query.trim().isNotEmpty || filter != PenjualanFilterCategory.all;

    final insets = MediaQuery.paddingOf(context);
    final showAction = View.of(context).viewInsets.bottom == 0;
    final buttonHeight = 52 * MediaQuery.textScalerOf(context).scale(1);
    final actionSpace = showAction ? buttonHeight + AppSpacing.xl : 0.0;

    return ColoredBox(
      color: colors.canvas,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: actionSpace),
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(penjualanViewModelProvider.notifier).refresh(),
                color: AppColors.primaryMint,
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        insets.top + AppSpacing.sm,
                        AppSpacing.lg,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.refreshing) ...[
                              const LinearProgressIndicator(minHeight: 2),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (state.error != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: colors.warning.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.input,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        state.error!,
                                        style: AppTypography.footnote.copyWith(
                                          color: colors.ink,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => ref
                                          .read(
                                            penjualanViewModelProvider.notifier,
                                          )
                                          .refresh(),
                                      child: const Text('Coba lagi'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            FeatureOverviewCard(
                              eyebrow: 'Total Pendapatan Bulan Ini',
                              title: formatRupiah(totalPendapatan),
                              subtitle:
                                  'Dari total $allCount transaksi penjualan '
                                  'terlaksana',
                              detail:
                                  '$paidCount lunas · '
                                  '${allCount - paidCount} belum lunas',
                              titleStyle: AppTypography.title1.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              illustration: FeatureIllustration.sales,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: SurfaceSearchField(
                                    controller: _searchController,
                                    label: 'Cari pembeli...',
                                    query: query,
                                    onChanged: (value) {
                                      ref
                                              .read(
                                                penjualanSearchQueryProvider
                                                    .notifier,
                                              )
                                              .state =
                                          value;
                                    },
                                    onClear: () {
                                      _searchController.clear();
                                      ref
                                              .read(
                                                penjualanSearchQueryProvider
                                                    .notifier,
                                              )
                                              .state =
                                          '';
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.ink,
                                    minimumSize: const Size(0, 56),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                    ),
                                    side: BorderSide(
                                      color: colors.controlBorder,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.input,
                                      ),
                                    ),
                                    textStyle: AppTypography.caption1.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _showFilterBottomSheet();
                                  },
                                  icon: Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: hasFilter
                                        ? colors.teal
                                        : colors.secondary,
                                  ),
                                  label: Text(
                                    'Filter',
                                    style: TextStyle(
                                      color: hasFilter
                                          ? colors.teal
                                          : colors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SurfaceSectionHeader(
                              title: 'Riwayat penjualan',
                              trailing: '${penjualanList.length} transaksi',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ),
                      ),
                    ),
                    if (penjualanList.isEmpty)
                      SliverToBoxAdapter(
                        child: SurfaceEmptyState(
                          illustration: hasFilter
                              ? FeatureIllustration.noResults
                              : FeatureIllustration.sales,
                          title: hasFilter
                              ? 'Penjualan tidak ditemukan.'
                              : 'Tidak ada data penjualan.',
                          message: hasFilter
                              ? 'Coba nama pembeli lain atau ubah filter status.'
                              : 'Catat transaksi pertama untuk melihat rekap '
                                    'omzet di sini.',
                          actionLabel: hasFilter ? 'Hapus filter' : null,
                          onAction: hasFilter ? _clearFilters : null,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: SliverList.separated(
                          itemCount: penjualanList.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = penjualanList[index];
                            return PenjualanCard(
                              key: ValueKey(item.id),
                              item: item,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CatatPenjualanPage(itemToEdit: item),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: insets.bottom + AppSpacing.sm),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showAction)
            Positioned(
              left: 0,
              right: 0,
              bottom: insets.bottom,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.canvas.withValues(alpha: 0),
                      colors.canvas.withValues(alpha: 0.92),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: RowButton(
                    label: '+ Catat Penjualan Baru',
                    backgroundColor: AppColors.accentLime,
                    textColor: AppColors.darkNavy,
                    borderRadius: AppRadius.pill,
                    height: buttonHeight,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CatatPenjualanPage(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
