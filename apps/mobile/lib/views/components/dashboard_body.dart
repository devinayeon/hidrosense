import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../theme/app_theme.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/base_col_card.dart';
import '../widgets/top_info_content.dart';
import '../widgets/card_icon_box.dart';
import '../pages/add_form_inventaris_page.dart';
import '../pages/seeding_form_page.dart';
import '../pages/connected_inventory_page.dart';
import '../pages/info_seeding_page.dart';
import '../pages/meja_nft_page.dart';
import '../pages/penjualan_page.dart';
import '../pages/panen_page.dart';
import '../pages/cuaca_page.dart';

class DashboardBody extends ConsumerWidget {
  const DashboardBody({super.key, this.onInventoryTap});

  final VoidCallback? onInventoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nursery = ref.watch(connectedNurseryProvider);
    final active = nursery.records.where((item) => item.status == 'aktif');
    final ready = active.where((item) => item.isReadyToMove).toList();
    final hasData = !nursery.loading && nursery.error == null;
    final actions =
        <({String title, IconData icon, Widget page, VoidCallback? onTap})>[
          (
            title: '+ Barang',
            icon: Icons.add_circle_outline,
            page: const AddFormInventarisPage(),
            onTap: null,
          ),
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

    return ColoredBox(
      color: AppColors.canvasWarm,
      child: RefreshIndicator(
        onRefresh: ref.read(connectedNurseryProvider.notifier).refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nursery.error != null)
                _DashboardAlert(
                  title: 'Data semaian belum dapat diperbarui',
                  subtitle: nursery.error!,
                  icon: Icons.error_outline,
                  backgroundColor: AppColors.dangerBg,
                  statusColor: AppColors.dangerRed,
                )
              else if (nursery.loading)
                const _DashboardAlert(
                  title: 'Memuat data semaian...',
                  subtitle: 'Memeriksa kesiapan pindah dari layanan.',
                  icon: Icons.sync,
                  backgroundColor: AppColors.infoBg,
                  statusColor: AppColors.infoBlue,
                )
              else if (ready.isEmpty)
                const _DashboardAlert(
                  title: 'Belum ada semaian siap pindah',
                  subtitle: 'Kesiapan mengikuti data penyemaian yang dimuat.',
                  icon: Icons.eco_outlined,
                  backgroundColor: AppColors.infoBg,
                  statusColor: AppColors.infoBlue,
                )
              else
                ...ready.map(
                  (item) => _DashboardAlert(
                    title: 'Semaian Siap Pindah',
                    subtitle:
                        '${item.batchName} • ${item.hssText}. Buka detail untuk pemindahan.',
                    icon: Icons.warning_amber_rounded,
                    backgroundColor: AppColors.warningBg,
                    statusColor: AppColors.warningOrange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InfoSeedingPage(sowingRecord: item),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: BaseColCard(
                      backgroundColor: AppColors.primaryMint,
                      child: TopInfoContent(
                        topText: 'Batch Semai Aktif',
                        middleText: hasData ? '${active.length} Batch' : '—',
                        bottomText: 'Pada daftar dimuat',
                        textColor: AppColors.textOnDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: BaseColCard(
                      backgroundColor: AppColors.accentLime,
                      child: TopInfoContent(
                        topText: 'Benih Disemai',
                        middleText: hasData
                            ? '${active.fold<int>(0, (count, item) => count + item.remainingSeedCount)} Butir'
                            : '—',
                        bottomText: 'Dari batch aktif dimuat',
                        textColor: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'AKSES CEPAT',
                style: AppTypography.footnote.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Wrap keeps the grid usable when text grows with accessibility settings.
                  final columns = constraints.maxWidth >= 600
                      ? 4
                      : constraints.maxWidth >= 280
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
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
                              key: ValueKey('dashboard-action-${action.title}'),
                              backgroundColor: AppColors.cardSurface,
                              padding: const EdgeInsets.all(AppSpacing.md),
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
                                  children: [
                                    CardIconBox(
                                      iconData: action.icon,
                                      backgroundColor: AppColors.primaryMint
                                          .withValues(alpha: 0.15),
                                      iconColor: AppColors.primaryDarkTeal,
                                      width: 48,
                                      height: 48,
                                      borderRadius: AppRadius.input,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      action.title,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.footnote.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
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
              const SizedBox(height: AppSpacing.lg),
              Text(
                'OPERASIONAL & BISNIS',
                style: AppTypography.footnote.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (ref
                      .watch(sessionProvider)
                      .user
                      ?.permissions
                      .contains('penjualan:read') ??
                  false) ...[
                _BusinessModuleCard(
                  title: 'Penjualan & Kasir',
                  subtitle: 'Pencatatan invoice, rekap omzet & transaksi',
                  icon: Icons.point_of_sale_outlined,
                  iconBg: AppColors.accentMintSoft,
                  iconColor: AppColors.primaryDarkTeal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PenjualanPage()),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              _BusinessModuleCard(
                title: 'Manajemen Panen',
                subtitle: 'Pencatatan sortasi, panen baru & log produksi',
                icon: Icons.agriculture_outlined,
                iconBg: AppColors.warningBg,
                iconColor: AppColors.warningOrange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PanenPage()),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _BusinessModuleCard(
                title: 'Kondisi & Cuaca Kebun',
                subtitle: 'Kondisi mikroklimat kebun & debit nutrisi',
                icon: Icons.wb_sunny_outlined,
                iconBg: AppColors.accentLime.withValues(alpha: 0.3),
                iconColor: AppColors.darkNavy,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CuacaPage()),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _BusinessModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RowInfoCardMd(
      backgroundColor: AppColors.cardSurface,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          CardIconBox(
            iconData: icon,
            backgroundColor: iconBg,
            iconColor: iconColor,
            width: 44,
            height: 44,
            borderRadius: AppRadius.input,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.subheadline.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _DashboardAlert extends StatelessWidget {
  const _DashboardAlert({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.statusColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: RowInfoCardMd(
        backgroundColor: backgroundColor,
        borderColor: statusColor,
        onTap: onTap,
        child: Row(
          children: [
            CardIconBox(
              iconData: icon,
              backgroundColor: statusColor,
              iconColor: AppColors.textOnDark,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.footnote.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle, style: AppTypography.footnote),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
