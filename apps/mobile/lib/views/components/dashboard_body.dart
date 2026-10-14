import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// Token tint glass khusus dashboard — diturunkan dari AppColors brand palette.
// Setiap kelompok card punya tint warna yang berbeda agar tidak monokrom.
// ─────────────────────────────────────────────────────────────────────────────
class _DashTint {
  /// Stat card: Batch Semai Aktif — mint brand
  static const Color statMint = Color(0x7239C6C5); // 45% primaryMint

  /// Stat card: Benih Disemai — lime accent
  static const Color statLime = Color(0x8CDDF45A); // 55% accentLime

  /// Quick action card — teal transparan, cukup pekat agar tinted terasa
  static const Color action = Color(0x3A39C6C5); // 23% primaryMint

  /// Business card: Penjualan — teal dalam
  static const Color bizTeal = Color(0x2A168681); // 16% primaryDarkTeal

  /// Business card: Panen — warm orange
  static const Color bizOrange = Color(0x28FF9A55); // 16% warningOrange

  /// Business card: Cuaca — lime muda
  static const Color bizLime = Color(0x35DDF45A); // 21% accentLime

  /// Alert: error — merah
  static Color alertRed(Color accent) => accent.withValues(alpha: 0.13);

  /// Alert: warning — oranye
  static Color alertWarning(Color accent) => accent.withValues(alpha: 0.14);
}

class DashboardBody extends ConsumerWidget {
  const DashboardBody({super.key, this.onInventoryTap});

  final VoidCallback? onInventoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((state) => state.user));
    final canRead = user?.permissions.contains('penyemaian:read') == true;
    final nursery = canRead
        ? ref.watch(connectedNurseryProvider)
        : const ConnectedNurseryState();
    final active = nursery.records.where((item) => item.status == 'aktif');
    final ready = active.where((item) => item.canTransfer).toList();
    final hasData = !nursery.loading && nursery.error == null;

    final actions =
        <({String title, IconData icon, Widget page, VoidCallback? onTap})>[
          (
            title: '+ Barang',
            icon: Icons.add_circle_outline,
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

    // Inset dari Scaffold: top = status bar + tinggi header,
    // bottom = tinggi floating navbar. Dipakai sebagai padding DI DALAM
    // scroll view agar konten bisa lewat di belakang header & navbar kaca.
    final insets = MediaQuery.paddingOf(context);

    // Stack: gradient mengisi PENUH layar (termasuk di balik status bar &
    // header transparan).
    return Stack(
      children: [
        // Layer 0: gradient background full screen
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFD6F5F3), // mint kuat kiri-atas
                  Color(0xFFF4FAF4), // hijau lembut tengah
                  Color(0xFFFAFAF7), // warm white kanan-bawah
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        // Layer 1: konten scrollable di atas gradient
        Positioned.fill(
          child: RefreshIndicator(
            edgeOffset: insets.top,
            onRefresh: canRead
                ? ref.read(connectedNurseryProvider.notifier).refresh
                : () async {},
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                insets.top + AppSpacing.sm, // mulai tepat di bawah header
                AppSpacing.md,
                insets.bottom + AppSpacing.md, // clearance floating navbar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Alert semaian ─────────────────────────────────────────
                  if (!canRead)
                    const Text('Penyemaian memerlukan izin baca.')
                  else if (nursery.error != null)
                    _DashboardGlassAlert(
                      title: 'Data semaian belum dapat diperbarui',
                      subtitle: nursery.error!,
                      icon: Icons.error_outline,
                      accentColor: AppColors.dangerRed,
                      tintColor: _DashTint.alertRed(AppColors.dangerRed),
                    )
                  else if (nursery.loading)
                    const _DashboardGlassAlert(
                      title: 'Memuat data semaian...',
                      subtitle: 'Memeriksa kesiapan pindah dari layanan.',
                      icon: Icons.sync,
                      accentColor: AppColors.infoBlue,
                      tintColor: Color(0x1E3B82F6), // 12% infoBlue
                    )
                  else if (ready.isEmpty)
                    const _DashboardGlassAlert(
                      title: 'Belum ada semaian siap pindah',
                      subtitle:
                          'Kesiapan mengikuti data penyemaian yang dimuat.',
                      icon: Icons.eco_outlined,
                      accentColor: AppColors.infoBlue,
                      tintColor: Color(0x1E3B82F6),
                    )
                  else
                    ...ready.map(
                      (item) => _DashboardGlassAlert(
                        title: 'Semaian Siap Pindah',
                        subtitle:
                            '${item.batchName} • ${item.hssText}. Buka detail untuk pemindahan.',
                        icon: Icons.warning_amber_rounded,
                        accentColor: AppColors.warningOrange,
                        tintColor: _DashTint.alertWarning(
                          AppColors.warningOrange,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InfoSeedingPage(sowingRecord: item),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.xxs),

                  // ─── Stat cards — tinted glass ─────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          // Mint tint: sesuai brand primaryMint
                          tintColor: _DashTint.statMint,
                          child: TopInfoContent(
                            topText: 'Batch Semai Aktif',
                            middleText: hasData
                                ? '${active.length} Batch'
                                : 'Belum dimuat',
                            bottomText: 'Pada daftar dimuat',
                            textColor: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          // Lime tint: sesuai accentLime brand
                          tintColor: _DashTint.statLime,
                          child: TopInfoContent(
                            topText: 'Benih Disemai',
                            middleText: hasData
                                ? '${active.fold<int>(0, (count, item) => count + item.remainingSeedCount)} Butir'
                                : 'Belum dimuat',
                            bottomText: 'Dari batch aktif dimuat',
                            textColor: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ─── Quick actions — mint tinted glass ─────────────────────
                  Text(
                    'AKSES CEPAT',
                    style: AppTypography.footnote.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                                child: _QuickActionGlassCard(
                                  key: ValueKey(
                                    'dashboard-action-${action.title}',
                                  ),
                                  title: action.title,
                                  icon: action.icon,
                                  onTap:
                                      action.onTap ??
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => action.page,
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

                  // ─── Operasional & bisnis — tiap card punya tint unik ─────
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
                    _BusinessModuleGlassCard(
                      title: 'Penjualan & Kasir',
                      subtitle: 'Pencatatan invoice, rekap omzet & transaksi',
                      icon: Icons.point_of_sale_outlined,
                      iconColor: AppColors.primaryDarkTeal,
                      // Teal tint — sesuai icon & brand color
                      tintColor: _DashTint.bizTeal,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PenjualanPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (ref
                          .watch(sessionProvider)
                          .user
                          ?.permissions
                          .contains('panen:read') ??
                      false) ...[
                    _BusinessModuleGlassCard(
                      title: 'Manajemen Panen',
                      subtitle: 'Pencatatan sortasi, panen baru & log produksi',
                      icon: Icons.agriculture_outlined,
                      iconColor: AppColors.warningOrange,
                      // Warm orange tint — sesuai warna panen/harvest
                      tintColor: _DashTint.bizOrange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PanenPage()),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  _BusinessModuleGlassCard(
                    title: 'Kondisi & Cuaca Kebun',
                    subtitle: 'Kondisi mikroklimat kebun & debit nutrisi',
                    icon: Icons.wb_sunny_outlined,
                    iconColor: AppColors.darkNavy,
                    // Lime-yellow tint — sesuai nuansa matahari/cuaca
                    tintColor: _DashTint.bizLime,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CuacaPage()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ), // close RefreshIndicator
        ), // close Positioned.fill
      ], // close Stack.children
    ); // close Stack
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Kartu akses cepat — mint tinted glass dengan icon teal.
class _QuickActionGlassCard extends StatefulWidget {
  const _QuickActionGlassCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_QuickActionGlassCard> createState() => _QuickActionGlassCardState();
}

class _QuickActionGlassCardState extends State<_QuickActionGlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: GlassContainer(
          // Mint tinted: lebih kuat dari default white agar terasa berwarna
          tintColor: _DashTint.action,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon box: teal border + mint bg
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDarkTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    border: Border.all(
                      color: AppColors.primaryMint.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: AppColors.primaryDarkTeal,
                    size: 22,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.title,
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
    );
  }
}

/// Kartu modul bisnis — tinted glass dengan warna unik per kategori.
class _BusinessModuleGlassCard extends StatefulWidget {
  const _BusinessModuleGlassCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.tintColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  /// Warna tint kaca — setiap kartu bisnis punya warna unik.
  final Color tintColor;

  final VoidCallback onTap;

  @override
  State<_BusinessModuleGlassCard> createState() =>
      _BusinessModuleGlassCardState();
}

class _BusinessModuleGlassCardState extends State<_BusinessModuleGlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: GlassContainer(
          tintColor: widget.tintColor,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CardIconBox(
                iconData: widget.icon,
                backgroundColor: widget.iconColor.withValues(alpha: 0.14),
                iconColor: widget.iconColor,
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
                      widget.title,
                      style: AppTypography.subheadline.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.iconColor.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner alert status semaian — tinted glass sesuai severity.
class _DashboardGlassAlert extends StatelessWidget {
  const _DashboardGlassAlert({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.tintColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  /// Tint glass sesuai warna severity alert.
  final Color tintColor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassContainer(
        tintColor: tintColor,
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CardIconBox(
              iconData: icon,
              backgroundColor: accentColor,
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
