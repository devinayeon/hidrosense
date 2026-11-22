import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Isi satu layar onboarding tanpa aksi.
///
/// Frame FigCraft memakai hero 460, ilustrasi 320 di dalamnya, lalu judul dan
/// badan mulai di y456. Pagination dan tombol sengaja tidak ikut di sini supaya
/// keduanya bisa dianimasikan sendiri oleh [V2OnboardingPage] dan tidak
/// tergeser bersama halaman.
class V2OnboardingSlide extends StatelessWidget {
  const V2OnboardingSlide({
    super.key,
    required this.illustration,
    required this.title,
    required this.body,
    required this.titleStyle,
    required this.heroHeight,
  });

  final String illustration;
  final String title;
  final String body;
  final TextStyle titleStyle;

  /// Tinggi hero; disesuaikan halaman induk dengan tinggi layar.
  final double heroHeight;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2OnboardingHero(illustration: illustration, height: heroHeight),
          Transform.translate(
            offset: const Offset(0, -4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
              child: Column(
                children: [
                  Text(title, textAlign: TextAlign.center, style: titleStyle),
                  const SizedBox(height: V2Space.lg),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: V2Type.body.copyWith(color: V2Colors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Latar hero onboarding: bidang biru dengan lengkung canvas di bawahnya.
class V2OnboardingHero extends StatelessWidget {
  const V2OnboardingHero({
    super.key,
    required this.illustration,
    this.height = 460,
  });

  final String illustration;
  final double height;

  @override
  Widget build(BuildContext context) {
    final illustrationSize = math.min(320.0, height * 0.695);
    final arcTop = height - 60;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ovalWidth = math.max(900.0, constraints.maxWidth * 2.3);
          return ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned.fill(child: ColoredBox(color: V2Colors.blue500)),
                Positioned(
                  left: (constraints.maxWidth - ovalWidth) / 2,
                  top: arcTop,
                  child: ClipOval(
                    child: SizedBox(
                      width: ovalWidth,
                      height: 500,
                      child: const ColoredBox(color: V2Colors.canvas),
                    ),
                  ),
                ),
                Positioned(
                  top: height * 84 / 460,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ExcludeSemantics(
                      child: Image.asset(
                        illustration,
                        width: illustrationSize,
                        height: illustrationSize,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
