import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Cincin siklus dari component set `CycleRing`.
///
/// Tiga lapis: track abu, jendela semai hijau, dan progres biru dengan
/// penutup lime di ujungnya.
class V2CycleRing extends StatelessWidget {
  const V2CycleRing({
    super.key,
    this.value = 23,
    this.total = 60,
    this.windowEnd = 15,
    this.unit = 'HSS',
    this.size = 112,
  });

  final int value;
  final int total;
  final int windowEnd;
  final String unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CycleRingPainter(
          progress: total == 0 ? 0 : (value / total).clamp(0, 1),
          window: total == 0 ? 0 : (windowEnd / total).clamp(0, 1),
          strokeWidth: size * 0.09,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(unit, style: V2Type.label.copyWith(color: V2Colors.muted)),
              Text(
                '$value',
                style: V2Type.value.copyWith(
                  fontSize: size * 0.25,
                  height: 1.1,
                ),
              ),
            ],
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
  });

  final double progress;
  final double window;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.shortestSide - strokeWidth) / 2,
    );
    const start = -math.pi / 2;

    final track = Paint()
      ..color = V2Colors.gray200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(rect.center, rect.width / 2, track);

    final windowPaint = Paint()
      ..color = V2Colors.green100
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, start, 2 * math.pi * window, false, windowPaint);

    final progressPaint = Paint()
      ..color = V2Colors.blue500
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, 2 * math.pi * progress, false, progressPaint);

    if (progress > 0) {
      final angle = start + 2 * math.pi * progress;
      final capCenter = Offset(
        rect.center.dx + rect.width / 2 * math.cos(angle),
        rect.center.dy + rect.width / 2 * math.sin(angle),
      );
      final cap = Paint()..color = V2Colors.lime400;
      canvas.drawCircle(capCenter, strokeWidth * 0.6, cap);
    }
  }

  @override
  bool shouldRepaint(_CycleRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.window != window ||
      oldDelegate.strokeWidth != strokeWidth;
}
