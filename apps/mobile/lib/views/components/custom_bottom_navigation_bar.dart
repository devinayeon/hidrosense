import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

/// Bottom navigation bar bergaya Liquid Glass — melayang di atas konten
/// dengan efek frosted glass, specular highlight, dan animated tab indicator.
///
/// Membutuhkan [Scaffold.extendBody] = true pada [Scaffold] induk agar
/// konten scroll terlihat menembus di bawah navbar dan efek blur tampak nyata.
class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: GlassContainer(
          borderRadius: AppRadius.pill,
          blurSigma: GlassContainer.barBlurSigma + 4,
          tintColor: isDark
              ? GlassContainer.barTintDark
              : GlassContainer.barTintLight,
          shadow: true,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              return _GlassNavItem(
                item: items[index],
                isSelected: index == currentIndex,
                onTap: () {
                  if (index != currentIndex) HapticFeedback.selectionClick();
                  onTap(index);
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Satu item tab di dalam floating glass navbar.
class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final BottomNavigationBarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark
        ? AppColors.primaryMint
        : const Color(0xFF0E756E);
    final inactiveColor = AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill indikator: "lensa kaca" kecil di atas glass bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: isSelected ? 56.0 : 40.0,
              height: 34.0,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.22 : 0.65),
                          AppColors.primaryMint.withValues(
                            alpha: isDark ? 0.20 : 0.22,
                          ),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: isSelected
                    ? Border.all(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.30 : 0.9,
                        ),
                        width: 0.8,
                      )
                    : null,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: IconTheme(
                    key: ValueKey(isSelected),
                    data: IconThemeData(
                      color: isSelected ? activeColor : inactiveColor,
                      size: 22,
                    ),
                    child: isSelected ? item.activeIcon : item.icon,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: AppTypography.caption2.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10.5,
              ),
              child: Text(item.label ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}
