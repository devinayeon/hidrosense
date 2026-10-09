import 'package:flutter/material.dart';
import '../pages/account_page.dart';
import '../widgets/custom_back_button.dart';
import '../theme/app_theme.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;
  final bool showBackButton;
  final bool showUserIcon;
  final VoidCallback? onBackPressed;
  final bool largeTitle;
  final double? toolbarHeight;
  final int? titleMaxLines;

  const Header({
    super.key,
    this.titleText = 'HidroSense',
    this.showBackButton = false,
    this.showUserIcon = true,
    this.onBackPressed,
    this.largeTitle = false,
    this.toolbarHeight,
    this.titleMaxLines,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight ?? (largeTitle ? 88 : kToolbarHeight));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      backgroundColor: AppColors.canvasWarm,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: showBackButton ? AppSpacing.sm : AppSpacing.md,
      leadingWidth: showBackButton ? 56 : 0,
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
      title: Text(
        titleText,
        maxLines: titleMaxLines ?? (largeTitle ? 1 : null),
        overflow: largeTitle ? TextOverflow.ellipsis : null,
        style: largeTitle
            ? AppTypography.largeTitle
            : AppTypography.title3.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
      ),
      actions: [
        if (showUserIcon)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _HeaderAvatarButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccountPage()),
                );
              },
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
            child: const Icon(
              Icons.person_outline,
              color: AppColors.darkNavy,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
