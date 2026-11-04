import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget permukaan Liquid Glass — menggabungkan [BackdropFilter] blur,
/// tint transparan, specular gradient, dan edge highlight ala Apple iOS 26.
///
/// Layer (bawah → atas):
/// 1. [BackdropFilter] memblur semua konten di belakang widget ini.
/// 2. Tint warna semi-transparan melapisi blur.
/// 3. Specular gradient (cahaya dari kiri-atas).
/// 4. Konten ([child]).
/// 5. Edge highlight: garis tepi gradient, terang di atas, redup di bawah.
///
/// Selalu dibungkus [RepaintBoundary] agar scroll di belakang tidak
/// memicu repaint GPU yang berlebihan.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blurSigma = AppGlass.blurSigma,
    this.borderRadius = AppRadius.card,
    this.tintColor,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.onTap,
    this.shadow = false,
  });

  /// Tint tipis khusus bar melayang (header capsule & bottom nav).
  /// Sengaja transparan supaya konten di belakang terlihat ter-blur.
  static const Color barTintLight = Color(0x4DFFFFFF); // putih ±30%
  static const Color barTintDark = Color(0x1FFFFFFF); // putih ±12%

  /// Blur untuk bar melayang.
  static const double barBlurSigma = 24.0;

  final Widget child;
  final double blurSigma;
  final double borderRadius;

  /// Override tint. Jika null, otomatis memakai [AppGlass.tintLight]
  /// atau [AppGlass.tintDark] sesuai brightness tema.
  final Color? tintColor;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final VoidCallback? onTap;

  /// Bayangan lembut di bawah kaca (untuk bar yang melayang).
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTint =
        tintColor ?? (isDark ? AppGlass.tintDark : AppGlass.tintLight);
    final specular = isDark ? AppGlass.specularDark : AppGlass.specularLight;
    final radius = BorderRadius.circular(borderRadius);

    final edgeTop = Colors.white.withValues(alpha: isDark ? 0.38 : 0.95);
    final edgeBottom = Colors.white.withValues(alpha: isDark ? 0.07 : 0.30);

    final Widget content =
        padding != null ? Padding(padding: padding!, child: child) : child;

    Widget glass = RepaintBoundary(
      child: Container(
        margin: margin,
        width: width,
        height: height,
        constraints: constraints,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
              tileMode: TileMode.mirror,
            ),
            child: CustomPaint(
              // Edge highlight digambar DI ATAS konten
              foregroundPainter: _GlassEdgePainter(
                radius: radius,
                top: edgeTop,
                bottom: edgeBottom,
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: effectiveTint)),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [specular, Colors.transparent],
                          stops: const [0.0, 0.55],
                        ),
                      ),
                    ),
                  ),
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      glass = GestureDetector(onTap: onTap, child: glass);
    }
    return glass;
  }
}

class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({
    required this.radius,
    required this.top,
    required this.bottom,
  });

  final BorderRadius radius;
  final Color top;
  final Color bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(rect);
    canvas.drawRRect(radius.toRRect(rect), paint);
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) =>
      old.radius != radius || old.top != top || old.bottom != bottom;
}