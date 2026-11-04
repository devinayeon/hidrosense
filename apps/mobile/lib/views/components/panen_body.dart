import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/harvest_record.dart';
import '../../data/models/transfer_record.dart';
import '../../viewmodels/panen_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/laporan_panen_page.dart';
import '../pages/panen_form_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_surface_colors.dart';
import '../widgets/feature_illustration.dart';
import '../widgets/feature_overview_card.dart';
import '../widgets/panen_card.dart';
import '../widgets/row_button.dart';
import '../widgets/surface_empty_state.dart';
import '../widgets/surface_notice.dart';
import '../widgets/surface_placeholder.dart';
import '../widgets/surface_search_field.dart';
import '../widgets/surface_section_header.dart';

class PanenBody extends ConsumerStatefulWidget {
  const PanenBody({super.key});

  @override
  ConsumerState<PanenBody> createState() => _PanenBodyState();
}

class _PanenBodyState extends ConsumerState<PanenBody> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    setState(() => _query = '');
    ref.read(panenFilterCategoryProvider.notifier).state =
        PanenFilterCategory.all;
  }

  List<TransferRecord> _filterBatches(List<TransferRecord> batches) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return batches;
    return batches.where((batch) {
      final searchable =
          'batch #${batch.id} meja #${batch.tableId} '
          '${batch.estimatedHarvestDate ?? ''} '
          '${batch.hss ?? ''} ${batch.hst ?? ''}';
      return searchable.toLowerCase().contains(query);
    }).toList();
  }

  List<HarvestRecord> _filterRecords(List<HarvestRecord> records) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return records;
    return records.where((record) {
      final tables = record.details
          .map((detail) => '${detail.tableCode} ${detail.tableId}')
          .join(' ');
      final searchable =
          'panen #${record.id} ${record.date} $tables ${record.note ?? ''}';
      return searchable.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider.select((state) => state.user));
    if (user == null || !user.permissions.contains('panen:read')) {
      return const Center(child: Text('Akses panen tidak diizinkan.'));
    }

    final state = ref.watch(panenViewModelProvider);
    final filter = ref.watch(panenFilterCategoryProvider);
    final vm = ref.read(panenViewModelProvider.notifier);
    final colors = AppSurfaceColors.of(context);
    final insets = MediaQuery.paddingOf(context);

    final hasAnyData = state.upcoming.isNotEmpty || state.records.isNotEmpty;
    final initialLoading = state.loading && !hasAnyData;
    final showAction =
        vm.canWrite &&
        vm.canReadBatches &&
        View.of(context).viewInsets.bottom == 0;
    final buttonHeight = 52 * MediaQuery.textScalerOf(context).scale(1);
    final actionSpace = showAction ? buttonHeight + AppSpacing.xl : 0.0;

    final allBatches = filter == PanenFilterCategory.completed
        ? const <TransferRecord>[]
        : state.upcoming;
    final allRecords = filter == PanenFilterCategory.upcoming
        ? const <HarvestRecord>[]
        : state.records;
    final batches = _filterBatches(allBatches);
    final records = _filterRecords(allRecords);
    final visibleCount = batches.length + records.length;

    final saleable = HarvestWeight.sum(
      state.records.map((record) => record.saleable),
    );
    final totalPlants = state.records.fold<int>(
      0,
      (total, record) => total + record.plantCount,
    );

    final showOverview = hasAnyData || initialLoading;
    final showControls = hasAnyData || initialLoading;
    final countLabel = state.loading ? 'Memuat...' : '$visibleCount data';
    final sectionTitle = switch (filter) {
      PanenFilterCategory.upcoming => 'Batch menunggu panen',
      PanenFilterCategory.completed => 'Riwayat panen',
      PanenFilterCategory.all => 'Daftar panen',
    };

    final errorWithoutData = state.error != null && !hasAnyData;
    final filterEmpty =
        !initialLoading &&
        state.error == null &&
        hasAnyData &&
        batches.isEmpty &&
        records.isEmpty;
    final hasNoData = !initialLoading && state.error == null && !hasAnyData;

    return ColoredBox(
      color: colors.canvas,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: actionSpace),
              child: RefreshIndicator(
                color: colors.teal,
                onRefresh: vm.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    insets.bottom + AppSpacing.sm,
                  ),
                  children: [
                    if (showOverview) ...[
                      FeatureOverviewCard(
                        eyebrow: 'PANEN',
                        title: initialLoading
                            ? 'Memuat panen...'
                            : '${saleable.wire} kg',
                        subtitle: state.loading
                            ? initialLoading
                                  ? 'Menyiapkan data dari layanan.'
                                  : 'Memuat data panen terbaru...'
                            : 'Akumulasi berat layak panen (belum dikurangi '
                                  'penjualan) dari ${state.records.length} '
                                  'laporan panen',
                        detail: !state.loading
                            ? '${state.upcoming.length} batch menunggu panen · '
                                  '$totalPlants tanaman tercatat'
                            : null,
                        titleStyle: AppTypography.title1.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        illustration: FeatureIllustration.harvest,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    if (state.error != null)
                      SurfaceNotice(
                        icon: CupertinoIcons.exclamationmark_circle,
                        text: state.error!,
                        error: true,
                        onRetry: state.loading ? null : vm.refresh,
                      ),
                    if (state.refreshWarning != null)
                      SurfaceNotice(
                        icon: CupertinoIcons.exclamationmark_triangle,
                        text: state.refreshWarning!,
                        onRetry: state.loading ? null : vm.refresh,
                      ),
                    if (!vm.canReadBatches &&
                        filter != PanenFilterCategory.completed)
                      const SurfaceNotice(
                        icon: CupertinoIcons.info_circle,
                        text:
                            'Akses budidaya diperlukan untuk melihat batch '
                            'mendatang.',
                      ),
                    if (state.loading && hasAnyData)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Semantics(
                          label: 'Memperbarui data panen',
                          liveRegion: true,
                          child: LinearProgressIndicator(
                            color: colors.teal,
                            backgroundColor: colors.mintSurface,
                            minHeight: 2,
                          ),
                        ),
                      ),
                    if (showControls) ...[
                      SurfaceSearchField(
                        controller: _searchController,
                        label: 'Cari panen atau batch...',
                        query: _query,
                        onChanged: (value) => setState(() => _query = value),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _FilterChips(
                        selected: filter,
                        upcomingCount: state.upcoming.length,
                        completedCount: state.records.length,
                        colors: colors,
                        onSelect: (category) {
                          ref.read(panenFilterCategoryProvider.notifier).state =
                              category;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SurfaceSectionHeader(
                        title: sectionTitle,
                        trailing: countLabel,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (initialLoading)
                      const SurfacePlaceholder()
                    else if (errorWithoutData)
                      const SurfaceEmptyState(
                        illustration: FeatureIllustration.harvest,
                        title: 'Data panen belum dapat ditampilkan.',
                        message: 'Periksa koneksi, lalu coba muat kembali.',
                      )
                    else if (hasNoData)
                      const SurfaceEmptyState(
                        illustration: FeatureIllustration.harvest,
                        title: 'Belum ada data panen.',
                        message:
                            'Catat hasil dari batch tanaman aktif untuk mulai '
                            'mengisi riwayat panen.',
                      )
                    else if (filterEmpty)
                      SurfaceEmptyState(
                        illustration: _query.trim().isNotEmpty
                            ? FeatureIllustration.noResults
                            : FeatureIllustration.harvest,
                        title: _query.trim().isNotEmpty
                            ? 'Data panen tidak ditemukan.'
                            : filter == PanenFilterCategory.upcoming
                            ? 'Belum ada batch menunggu panen.'
                            : 'Belum ada riwayat panen.',
                        message: _query.trim().isNotEmpty
                            ? 'Coba kata kunci lain atau tampilkan semua data.'
                            : 'Semua data panen masih dapat dilihat dengan '
                                  'filter Semua Data.',
                        actionLabel: 'Tampilkan semua',
                        onAction: _resetFilters,
                      )
                    else ...[
                      for (final batch in batches)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: PanenCard(
                            key: ValueKey('batch-${batch.id}'),
                            title: 'Batch #${batch.id}',
                            subtitle:
                                'Meja #${batch.tableId} • '
                                '${batch.activePlants} tanaman aktif',
                            result:
                                'Estimasi '
                                '${batch.estimatedHarvestDate ?? 'belum tersedia'}\n'
                                'HSS ${batch.hss ?? 'belum tersedia'} • '
                                'HST ${batch.hst ?? 'belum tersedia'}',
                            completed: false,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PanenFormPage(transferId: batch.id),
                              ),
                            ),
                          ),
                        ),
                      for (final record in records)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: PanenCard(
                            key: ValueKey('harvest-${record.id}'),
                            title: 'Panen #${record.id}',
                            subtitle:
                                '${record.date} • '
                                '${record.details.map((detail) => detail.tableCode).toSet().join(', ')}',
                            result:
                                'Layak panen ${record.saleable.wire} kg • '
                                'Total ${record.total?.wire ?? 'belum tercatat'}'
                                '${record.total == null ? '' : ' kg'}',
                            completed: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LaporanPanenPage(harvestId: record.id),
                              ),
                            ),
                          ),
                        ),
                    ],
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
                    label: 'Catat Hasil Panen Baru',
                    backgroundColor: AppColors.accentLime,
                    textColor: AppColors.darkNavy,
                    borderRadius: AppRadius.pill,
                    height: buttonHeight,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      vm.beginDraft();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PanenFormPage(),
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.upcomingCount,
    required this.completedCount,
    required this.colors,
    required this.onSelect,
  });

  final PanenFilterCategory selected;
  final int upcomingCount;
  final int completedCount;
  final AppSurfaceColors colors;
  final ValueChanged<PanenFilterCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final options = <(PanenFilterCategory, String)>[
      (PanenFilterCategory.all, 'Semua Data'),
      (PanenFilterCategory.upcoming, 'Mendatang ($upcomingCount)'),
      (PanenFilterCategory.completed, 'Selesai ($completedCount)'),
    ];
    final chipAnimation = MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 140),
            reverseDuration: Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
          );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(option.$2),
                selected: selected == option.$1,
                showCheckmark: false,
                selectedColor: AppColors.accentLime,
                backgroundColor: colors.surface,
                labelStyle: AppTypography.subheadline.copyWith(
                  color: selected == option.$1
                      ? AppColors.darkNavy
                      : colors.ink,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: selected == option.$1
                      ? AppColors.darkNavy
                      : colors.controlBorder,
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                chipAnimationStyle: ChipAnimationStyle(
                  selectAnimation: chipAnimation,
                  enableAnimation: chipAnimation,
                ),
                onSelected: (_) {
                  if (selected != option.$1) {
                    HapticFeedback.selectionClick();
                  }
                  onSelect(option.$1);
                },
              ),
            ),
        ],
      ),
    );
  }
}
