import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/connected_table_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/form_meja_nft_page.dart';
import '../pages/info_meja_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_surface_colors.dart';
import '../widgets/feature_illustration.dart';
import '../widgets/feature_overview_card.dart';
import '../widgets/meja_nft_card.dart';
import '../widgets/row_button.dart';
import '../widgets/surface_empty_state.dart';
import '../widgets/surface_notice.dart';
import '../widgets/surface_placeholder.dart';
import '../widgets/surface_search_field.dart';
import '../widgets/surface_section_header.dart';

class MejaNftBody extends ConsumerStatefulWidget {
  const MejaNftBody({super.key});

  @override
  ConsumerState<MejaNftBody> createState() => _MejaNftBodyState();
}

class _MejaNftBodyState extends ConsumerState<MejaNftBody> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(connectedTableProvider).searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    final notifier = ref.read(connectedTableProvider.notifier);
    notifier.setSearchQuery('');
    notifier.setStatusFilter(null);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider.select((state) => state.user));
    if (user == null || !user.permissions.contains('budidaya:read')) {
      return const Center(child: Text('Akses meja tanam tidak diizinkan.'));
    }

    final canWrite = user.permissions.contains('budidaya:write');
    final state = ref.watch(connectedTableProvider);
    final notifier = ref.read(connectedTableProvider.notifier);
    final refresh = notifier.refresh;
    final items = state.filtered;
    final colors = AppSurfaceColors.of(context);

    final insets = MediaQuery.paddingOf(context);
    final initialLoading = state.loading && state.records.isEmpty;
    final showAction = canWrite && View.of(context).viewInsets.bottom == 0;
    final buttonHeight = 52 * MediaQuery.textScalerOf(context).scale(1);
    final actionSpace = showAction ? buttonHeight + AppSpacing.xl : 0.0;

    final activeCount = state.counts['aktif'] ?? 0;
    final maintenanceCount = state.counts['perawatan'] ?? 0;
    final totalHoles = state.records.fold<int>(
      0,
      (total, item) => total + item.holeCount,
    );
    final usedHoles = state.records.fold<int>(
      0,
      (total, item) => total + item.activePlants,
    );
    final occupancy = totalHoles == 0
        ? 0
        : ((usedHoles / totalHoles) * 100).round();
    final failed = state.error != null && state.records.isEmpty;
    final countLabel = initialLoading ? 'Memuat...' : '${items.length} meja';

    return ColoredBox(
      color: colors.canvas,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: actionSpace),
              child: RefreshIndicator(
                color: colors.teal,
                onRefresh: refresh,
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.records.isNotEmpty || initialLoading) ...[
                              FeatureOverviewCard(
                                eyebrow: 'MEJA NFT',
                                title: initialLoading
                                    ? 'Memuat meja...'
                                    : '${state.records.length} meja tanam',
                                subtitle: initialLoading
                                    ? 'Menyiapkan data dari layanan.'
                                    : '$activeCount aktif · '
                                          '$maintenanceCount perawatan',
                                detail: !initialLoading && totalHoles > 0
                                    ? '$usedHoles/$totalHoles lubang terisi · '
                                          '$occupancy%'
                                    : null,
                                illustration: FeatureIllustration.table,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                            ],
                            if (state.error != null && state.records.isNotEmpty)
                              SurfaceNotice(
                                icon: CupertinoIcons.exclamationmark_circle,
                                text: state.error!,
                                error: true,
                                onRetry: state.loading ? null : refresh,
                              ),
                            if (state.loading && state.records.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Semantics(
                                  label: 'Memperbarui meja tanam',
                                  liveRegion: true,
                                  child: LinearProgressIndicator(
                                    color: colors.teal,
                                    backgroundColor: colors.mintSurface,
                                    minHeight: 2,
                                  ),
                                ),
                              ),
                            SurfaceSearchField(
                              controller: _searchController,
                              label: 'Cari meja tanam...',
                              query: state.searchQuery,
                              onChanged: notifier.setSearchQuery,
                              onClear: () {
                                _searchController.clear();
                                notifier.setSearchQuery('');
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _StatusChips(
                              selected: state.statusFilter,
                              colors: colors,
                              onSelect: notifier.setStatusFilter,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SurfaceSectionHeader(
                              title: 'Daftar meja tanam',
                              trailing: countLabel,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ),
                      ),
                    ),
                    if (initialLoading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: SliverList.builder(
                          itemCount: 3,
                          itemBuilder: (_, _) => const SurfacePlaceholder(),
                        ),
                      )
                    else if (items.isEmpty)
                      SliverToBoxAdapter(
                        child: SurfaceEmptyState(
                          illustration: failed || state.records.isEmpty
                              ? FeatureIllustration.table
                              : FeatureIllustration.noResults,
                          title: failed
                              ? 'Data meja tanam belum dapat ditampilkan.'
                              : state.records.isEmpty
                              ? 'Belum ada meja tanam.'
                              : 'Meja tanam tidak ditemukan.',
                          message: failed
                              ? 'Periksa koneksi, lalu coba muat kembali.'
                              : state.records.isEmpty
                              ? 'Tambahkan meja pertama untuk mulai mengatur '
                                    'kapasitas tanam NFT.'
                              : 'Coba kode meja lain atau hapus filter yang '
                                    'sedang aktif.',
                          actionLabel: failed
                              ? 'Coba lagi'
                              : state.records.isEmpty
                              ? null
                              : 'Hapus filter',
                          onAction: failed
                              ? refresh
                              : state.records.isEmpty
                              ? null
                              : _resetFilters,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: SliverList.separated(
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return MejaNftCard(
                              key: ValueKey(item.id),
                              item: item,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InfoMejaPage(tableRecord: item),
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
                    label: '+ Tambah Meja NFT Baru',
                    backgroundColor: AppColors.accentLime,
                    textColor: AppColors.darkNavy,
                    borderRadius: AppRadius.pill,
                    height: buttonHeight,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FormMejaNftPage(),
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

class _StatusChips extends StatelessWidget {
  const _StatusChips({
    required this.selected,
    required this.colors,
    required this.onSelect,
  });

  final String? selected;
  final AppSurfaceColors colors;
  final ValueChanged<String?> onSelect;

  static const _options = <(String?, String)>[
    (null, 'Semua'),
    ('tersedia', 'Aktif'),
    ('pemeliharaan', 'Perawatan'),
  ];

  @override
  Widget build(BuildContext context) {
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
          for (final option in _options)
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
                      ? colors.teal
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
