import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/add_form_inventaris_page.dart';
import '../pages/connected_inventory_page.dart';
import '../pages/cuaca_page.dart';
import '../pages/info_seeding_page.dart';
import '../pages/meja_nft_page.dart';
import '../pages/panen_page.dart';
import '../pages/penjualan_page.dart';
import '../pages/seeding_form_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_surface_colors.dart';
import '../widgets/feature_illustration.dart';
import '../widgets/feature_overview_card.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/surface_section_header.dart';

class DashboardBody extends ConsumerWidget {
  const DashboardBody({super.key, this.onInventoryTap});

  final VoidCallback? onInventoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((state) => state.user));
    final canReadNursery =
        user?.permissions.contains('penyemaian:read') == true;
    final nursery = canReadNursery
        ? ref.watch(connectedNurseryProvider)
        : const ConnectedNurseryState();
    final active = nursery.records.where((item) => item.status == 'aktif');
    final ready = active.where((item) => item.canTransfer).toList();
    final hasData = !nursery.loading && nursery.error == null;
    final colors = AppSurfaceColors.of(context);

    final actions =
        <({String title, IconData icon, Widget page, VoidCallback? onTap})>[
          (
            title: '+ Barang',
            icon: Icons.inventory_2_outlined,
            page: const AddFormInventarisPage(),
            onTap: null,
          ),
          if (user?.permissions.contains('penyemaian:write') == true)
            (
              title: '+ Semai',
              icon: Icons.eco_outlined,
              page: const SeedingFormPage(),
              onTap: null,
            ),
          (
            title: 'Cek Stok',
            icon: Icons.view_in_ar_outlined,
            page: const ConnectedInventoryPage(),
            onTap: onInventoryTap,
          ),
          (
            title: 'Meja NFT',
            icon: Icons.table_restaurant_outlined,
            page: const MejaNftPage(),
            onTap: null,
          ),
        ];

    final insets = MediaQuery.paddingOf(context);

    return ColoredBox(
      color: colors.canvas,
      child: RefreshIndicator(
        color: colors.teal,
        edgeOffset: insets.top,
        onRefresh: canReadNursery
            ? ref.read(connectedNurseryProvider.notifier).refresh
            : () async {},
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                insets.top + AppSpacing.sm,
                AppSpacing.lg,
                insets.bottom + AppSpacing.xxxl,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user != null) ...[
                      FeatureOverviewCard(
                        eyebrow: 'SELAMAT DATANG',
                        title: 'Halo, ${user.name}',
                        subtitle:
                            'Peran: '
                            '${user.role == 'petani' ? 'Petani' : 'Pegawai'} · '
                            'Hidrosense Garden',
                        detail: canReadNursery && hasData
                            ? '${active.length} batch aktif · '
                                  '${ready.length} siap pindah'
                            : null,
                        illustration: FeatureIllustration.nursery,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ─── Alert semaian ─────────────────────────────────────────
                    if (!canReadNursery)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          'Penyemaian memerlukan izin baca.',
                          style: AppTypography.subheadline.copyWith(
                            color: colors.secondary,
                          ),
                        ),
                      )
                    else if (nursery.error != null)
                      _DashboardAlert(
                        title: 'Data semaian belum dapat diperbarui',
                        subtitle: nursery.error!,
                        icon: Icons.error_outline,
                        accentColor: AppColors.dangerRed,
                      )
                    else if (nursery.loading)
                      const _DashboardAlert(
                        title: 'Memuat data semaian...',
                        subtitle: 'Memeriksa kesiapan pindah dari layanan.',
                        icon: Icons.sync,
                        accentColor: AppColors.infoBlue,
                      )
                    else if (ready.isEmpty)
                      const _DashboardAlert(
                        title: 'Belum ada semaian siap pindah',
                        subtitle:
                            'Kesiapan mengikuti data penyemaian yang dimuat.',
                        icon: Icons.eco_outlined,
                        accentColor: AppColors.infoBlue,
                      )
                    else
                      ...ready.map(
                        (item) => _DashboardAlert(
                          title: 'Semaian Siap Pindah',
                          subtitle:
                              '${item.batchName} • ${item.hssText}. '
                              'Buka detail untuk pemindahan.',
                          icon: Icons.warning_amber_rounded,
                          accentColor: AppColors.warningOrange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  InfoSeedingPage(sowingRecord: item),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.xs),

                    // ─── Statistik semaian ─────────────────────────────────────
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final first = _DashboardStat(
                          label: 'Batch Semai Aktif',
                          value: hasData
                              ? '${active.length} Batch'
                              : 'Belum dimuat',
                          caption: 'Dari daftar yang dimuat',
                        );
                        final second = _DashboardStat(
                          label: 'Benih Disemai',
                          value: hasData
                              ? '${active.fold<int>(0, (count, item) => count + item.remainingSeedCount)} '
                                    'Butir'
                              : 'Belum dimuat',
                          caption: 'Sisa benih batch aktif',
                        );
                        if (constraints.maxWidth < 300) {
                          return Column(
                            children: [
                              first,
                              const SizedBox(height: AppSpacing.sm),
                              second,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: first),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: second),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ─── Akses cepat ───────────────────────────────────────────
                    SurfaceSectionHeader(
                      title: 'Akses cepat',
                      trailing: '${actions.length} pintasan',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 600
                            ? 4
                            : constraints.maxWidth >= 280
                            ? 2
                            : 1;
                        final width =
                            (constraints.maxWidth -
                                AppSpacing.sm * (columns - 1)) /
                            columns;
                        return Wrap(
                          key: const ValueKey('dashboard-quick-actions'),
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: actions
                              .map(
                                (action) => SizedBox(
                                  width: width,
                                  child: RowInfoCardMd(
                                    backgroundColor: colors.surface,
                                    borderColor: colors.border,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs,
                                      vertical: 14,
                                    ),
                                    onTap:
                                        action.onTap ??
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => action.page,
                                          ),
                                        ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: colors.mintSurface,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.input,
                                                  ),
                                            ),
                                            child: Icon(
                                              action.icon,
                                              color: colors.teal,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            action.title,
                                            textAlign: TextAlign.center,
                                            style: AppTypography.footnote
                                                .copyWith(
                                                  color: colors.ink,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ─── Operasional & bisnis ──────────────────────────────────
                    const SurfaceSectionHeader(title: 'Operasional & bisnis'),
                    const SizedBox(height: AppSpacing.sm),
                    if (user?.permissions.contains('penjualan:read') == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _BusinessModuleCard(
                          title: 'Penjualan & Kasir',
                          subtitle:
                              'Pencatatan invoice, rekap omzet & transaksi',
                          icon: Icons.point_of_sale_outlined,
                          accentColor: AppColors.primaryDarkTeal,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PenjualanPage(),
                            ),
                          ),
                        ),
                      ),
                    if (user?.permissions.contains('panen:read') == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _BusinessModuleCard(
                          title: 'Manajemen Panen',
                          subtitle:
                              'Pencatatan sortasi, panen baru & log produksi',
                          icon: Icons.agriculture_outlined,
                          accentColor: AppColors.warningOrange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PanenPage(),
                            ),
                          ),
                        ),
                      ),
                    if (user?.permissions.contains('cuaca:read') == true)
                      _BusinessModuleCard(
                        title: 'Kondisi & Cuaca Kebun',
                        subtitle: 'Kondisi mikroklimat kebun & debit nutrisi',
                        icon: Icons.wb_sunny_outlined,
                        accentColor: AppColors.darkNavy,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CuacaPage()),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Banner status semaian dengan aksen warna di atas permukaan kartu.
class _DashboardAlert extends StatelessWidget {
  const _DashboardAlert({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: RowInfoCardMd(
        backgroundColor: colors.surface,
        borderColor: accentColor.withValues(alpha: 0.35),
        padding: const EdgeInsets.all(AppSpacing.sm),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.footnote.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: AppTypography.footnote.copyWith(
                      color: colors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                CupertinoIcons.chevron_right,
                color: colors.secondary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

/// Dua metrik utama semaian di bawah banner status.
class _DashboardStat extends StatelessWidget {
  const _DashboardStat({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);
    return RowInfoCardMd(
      backgroundColor: colors.surface,
      borderColor: colors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.footnote.copyWith(
              color: colors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.tabular(
              AppTypography.title3.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            caption,
            style: AppTypography.caption1.copyWith(color: colors.secondary),
          ),
        ],
      ),
    );
  }
}

/// Kartu modul operasional dengan ikon, judul, dan ringkasan singkat.
class _BusinessModuleCard extends StatelessWidget {
  const _BusinessModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);
    return RowInfoCardMd(
      backgroundColor: colors.surface,
      borderColor: colors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.subheadline.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: AppTypography.caption1.copyWith(
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(CupertinoIcons.chevron_right, color: colors.secondary, size: 16),
        ],
      ),
    );
  }
}
