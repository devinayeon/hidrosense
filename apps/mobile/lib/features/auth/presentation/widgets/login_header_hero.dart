import 'package:flutter/material.dart';
import '../../../../core/widgets/wavy_header_clipper.dart';

/// Place outside the top SafeArea so the artwork reaches the status bar.
class LoginHeaderHero extends StatelessWidget {
  final double? height;

  /// Custom asset path override for the hero illustration.
  final String imageAssetPath;

  final bool showSoftOverlay;

  static const _screenHeightFraction = 0.32;
  static const _minimumHeight = 240.0;
  static const _maximumHeight = 300.0;
  static const _placeholder = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
    ),
  );

  const LoginHeaderHero({
    super.key,
    this.height,
    this.imageAssetPath =
        'assets/side-ultility/Modern Hydroponic Greenhouse Row.png',
    this.showSoftOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final effectiveHeight =
        height ??
        (screenHeight * _screenHeightFraction).clamp(
          _minimumHeight,
          _maximumHeight,
        );

    return SizedBox(
      width: double.infinity,
      height: effectiveHeight,
      child: ClipPath(
        clipper: const TopHeroWaveClipper(),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(decoration: _placeholder),
            Image.asset(
              imageAssetPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
            if (showSoftOverlay)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x1A000000)],
                    stops: [0.75, 1.0],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
