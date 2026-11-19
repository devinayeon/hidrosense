import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Status bar dan home indicator perangkat (iOS frame 390x844).
class V2StatusBar extends StatelessWidget {
  const V2StatusBar({super.key, this.time = '9:41', this.color = V2Colors.ink});

  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
      child: Row(
        children: [
          Text(time, style: V2Type.bodyStrong.copyWith(color: color)),
          const Spacer(),
          Icon(Icons.signal_cellular_alt, size: 18, color: color),
          const SizedBox(width: V2Space.xs),
          Icon(Icons.wifi, size: 18, color: color),
          const SizedBox(width: V2Space.xs),
          Icon(Icons.battery_full, size: 20, color: color),
        ],
      ),
    );
  }
}

/// Bar putih 134x5 di bawah layar.
class V2HomeIndicator extends StatelessWidget {
  const V2HomeIndicator({
    super.key,
    this.color = V2Colors.ink,
    this.height = 34,
  });

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: V2Space.sm),
          child: Container(
            width: 134,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}
