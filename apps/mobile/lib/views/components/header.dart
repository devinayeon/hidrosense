import 'package:flutter/material.dart';
import '../pages/account_page.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/glass_container.dart';
import '../theme/app_theme.dart';
import '../widgets/inventory_illustration.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;
  final bool showBackButton;
  final bool showUserIcon;
  final VoidCallback? onBackPressed;
  final bool largeTitle;
  final double? toolbarHeight;
  final int? titleMaxLines;
  final bool useThemeColors;
  final List<Widget>? actions;
  final bool isScrolled;
  final bool capsuleOnScroll;

  const Header({
    super.key,
    this.titleText = 'HidroSense',
    this.showBackButton = false,
    this.showUserIcon = true,
    this.onBackPressed,
    this.largeTitle = false,
    this.toolbarHeight,
    this.titleMaxLines,
    this.useThemeColors = false,
    this.actions,
    this.isScrolled = false,
    this.capsuleOnScroll = false,
  });

  /// Tinggi SENGAJA konstan (tidak tergantung [isScrolled]).
  /// Kalau tinggi berubah saat scroll, padding atas body ikut berubah
  /// (karena body berada di belakang header) → konten loncat / flicker.
  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight ?? (largeTitle ? 88 : kToolbarHeight));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── CAPSULE MODE (aktif saat di-scroll) ────────────────────────────────
    if (capsuleOnScroll && isScrolled) {
      return AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: preferredSize.height,
        automaticallyImplyLeading: false,
        leadingWidth: 0,
        titleSpacing: 0,
        flexibleSpace: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: GlassContainer(
                borderRadius: AppRadius.pill,
                blurSigma: GlassContainer.barBlurSigma,
                tintColor: isDark
                    ? GlassContainer.barTintDark
                    : GlassContainer.barTintLight,
                shadow: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xxs,
                ),
                child: Row(
                  children: [
                    if (showBackButton) ...[
                      CustomBackButton(
                        onTap:
                            onBackPressed ?? () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Expanded(
                      child: Text(
                        titleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headline.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    ...?actions,
                    if (showUserIcon)
                      _HeaderAvatarButton(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountPage(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── STANDARD MODE (di posisi atas / belum di-scroll) ───────────────────
    final bgColor = useThemeColors
        ? Theme.of(context).colorScheme.surface
        : AppColors.canvasWarm;

    return AppBar(
      toolbarHeight: preferredSize.height,
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: showBackButton ? AppSpacing.sm : AppSpacing.md,
      leadingWidth: showBackButton ? (useThemeColors ? 64 : 56) : 0,
      leading: showBackButton
          ? Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Center(
                child: CustomBackButton(
                  onTap: onBackPressed ?? () => Navigator.maybePop(context),
                ),
              ),
            )
          : null,
      title: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: largeTitle
            ? AppTypography.largeTitle
            : AppTypography.title3.copyWith(
                fontWeight: FontWeight.w800,
                color: useThemeColors
                    ? Theme.of(context).colorScheme.onSurface
                    : AppColors.textPrimary,
              ),
        child: Text(
          titleText,
          maxLines: titleMaxLines ?? (largeTitle ? 1 : null),
          overflow: largeTitle ? TextOverflow.ellipsis : null,
        ),
      ),
      actions: [
        ...?actions,
        if (showUserIcon)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _HeaderAvatarButton(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountPage()),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderAvatarButton extends StatefulWidget {
  final VoidCallback onTap;
  const _HeaderAvatarButton({required this.onTap});

  @override
  State<_HeaderAvatarButton> createState() => _HeaderAvatarButtonState();
}

class _HeaderAvatarButtonState extends State<_HeaderAvatarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.accentLime,
              shape: BoxShape.circle,
              boxShadow: AppShadows.subtle,
            ),
            child: const InventoryIllustration(
              asset: InventoryIllustration.avatar,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}
