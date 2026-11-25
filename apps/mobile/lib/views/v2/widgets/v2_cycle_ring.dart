import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Cincin siklus dari component set `CycleRing`.
///
/// Tiga lapis: track penuh, jendela semai, lalu progres berujung bulat.
/// Ukuran `Size=Compact` (112) memakai ketebalan 12 dan dipakai di kartu hero
/// beranda; ukuran `Size=Large` (224) memakai ketebalan 20 dan bisa menampilkan
/// garis penanda HSS (frame 2.7).
class V2CycleRing extends StatelessWidget {
  const V2CycleRing({
    super.key,
    this.value = 23,
    this.total = 60,
    this.windowEnd = 15,
    this.unit = 'HSS',
    this.size = 112,
    this.strokeWidth,
    this.trackColor = V2Colors.gray200,
    this.windowColor = V2Colors.green100,
    this.progressColor = V2Colors.blue500,
    this.contentColor = V2Colors.ink,
    this.unitColor = V2Colors.muted,
    this.valueStyle,
    this.tickValue,
    this.tickColor = V2Colors.ink,
  });

  final int value;
  final int total;

  /// Akhir jendela semai (HSS 15 dari 60 = 90 derajat).
  final int windowEnd;
  final String unit;
  final double size;

  /// Kalau null, dipakai rasio desain per ukuran (112 -> 12, 224 -> 20).
  final double? strokeWidth;
  final Color trackColor;
  final Color windowColor;
  final Color progressColor;
  final Color contentColor;
  final Color unitColor;

  /// Kalau null, gaya angka dipilih dari ukuran: 112 memakai 28/36 dan
  /// 224 memakai 34/40.
  final TextStyle? valueStyle;

  /// Nilai HSS yang ditandai garis pendek 22x3 di tepi cincin.
  final int? tickValue;
  final Color tickColor;

  @override
  Widget build(BuildContext context) {
    final stroke = strokeWidth ?? size * (1 - 0.7857142) / 2;
    final big = size > 140;
    final numberStyle = valueStyle ?? (big ? V2Type.display : V2Type.value);
    final tick = tickValue == null || total == 0
        ? null
        : (tickValue! / total).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CycleRingPainter(
          progress: total == 0 ? 0 : (value / total).clamp(0.0, 1.0),
          window: total == 0 ? 0 : (windowEnd / total).clamp(0.0, 1.0),
          strokeWidth: stroke,
          trackColor: trackColor,
          windowColor: windowColor,
          progressColor: progressColor,
          tick: tick,
          tickColor: tickColor,
        ),
        child: Center(
          child: Padding(
            // Teks tengah dibatasi ke lingkaran dalam; `FittedBox` menyusutkan
            // "HSS" + angka saat skala teks sistem besar, bukan meluap keluar
            // cincin (BUG-24).
            padding: EdgeInsets.all(stroke * 0.9),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(unit, style: V2Type.label.copyWith(color: unitColor)),
                  Text(
                    '$value',
                    style: numberStyle.copyWith(color: contentColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CycleRingPainter extends CustomPainter {
  const _CycleRingPainter({
    required this.progress,
    required this.window,
    required this.strokeWidth,
    required this.trackColor,
    required this.windowColor,
    required this.progressColor,
    required this.tick,
    required this.tickColor,
  });

  final double progress;
  final double window;
  final double strokeWidth;
  final Color trackColor;
  final Color windowColor;
  final Color progressColor;
  final double? tick;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    if (window > 0) {
      final windowPaint = Paint()
        ..color = windowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, 2 * math.pi * window, false, windowPaint);
    }

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, 2 * math.pi * progress, false, progressPaint);
    }

    final tickAt = tick;
    if (tickAt != null) {
      const half = 11.0;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(start + 2 * math.pi * tickAt);
      canvas.drawLine(
        Offset(-half + radius, 0),
        Offset(half + radius, 0),
        Paint()
          ..color = tickColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.butt,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CycleRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.window != window ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.windowColor != windowColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.tick != tick ||
      oldDelegate.tickColor != tickColor;
}
