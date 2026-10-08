import 'package:flutter/material.dart';

class TopHeroWaveClipper extends CustomClipper<Path> {
  const TopHeroWaveClipper();

  static const _waveDepthFraction = 0.22;

  @override
  Path getClip(Size size) {
    final width = size.width;
    final bottom = size.height;
    final depth = bottom * _waveDepthFraction;

    return Path()
      ..lineTo(0, bottom - depth * 0.5)
      ..cubicTo(
        width * 0.10,
        bottom - depth * 0.75,
        width * 0.18,
        bottom - depth,
        width * 0.28,
        bottom - depth,
      )
      ..cubicTo(
        width * 0.40,
        bottom - depth,
        width * 0.50,
        bottom - depth * 0.55,
        width * 0.60,
        bottom - depth * 0.55,
      )
      ..cubicTo(
        width * 0.67,
        bottom - depth * 0.55,
        width * 0.70,
        bottom - depth,
        width * 0.80,
        bottom - depth,
      )
      ..cubicTo(
        width * 0.91,
        bottom - depth,
        width * 0.91,
        bottom - depth * 0.2,
        width,
        bottom,
      )
      ..lineTo(width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
