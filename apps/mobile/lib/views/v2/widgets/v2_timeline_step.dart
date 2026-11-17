import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

enum V2TimelineState { done, active, pending }

/// Satu langkah linimasa dari component set `TimelineStep` (342x56).
///
/// Marker 32px, judul 16/24, dan sub 14/20. Tidak ada garis penghubung antar
/// langkah: jarak antar langkah diatur pemanggil (gap 8 di frame 2.7).
class V2TimelineStep extends StatelessWidget {
  const V2TimelineStep({
    super.key,
    required this.title,
    required this.subtitle,
    this.state = V2TimelineState.pending,
  });

  final String title;
  final String subtitle;
  final V2TimelineState state;

  @override
  Widget build(BuildContext context) {
    final pending = state == V2TimelineState.pending;
    final (markerBackground, markerBorder, markerForeground) = switch (state) {
      V2TimelineState.done => (V2Colors.green100, null, V2Colors.green700),
      V2TimelineState.active => (
        V2Colors.blue50,
        V2Colors.blue700,
        V2Colors.ink,
      ),
      V2TimelineState.pending => (
        Colors.transparent,
        V2Colors.borderStrong,
        V2Colors.muted,
      ),
    };

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: markerBackground,
              shape: BoxShape.circle,
              border: markerBorder == null
                  ? null
                  : Border.all(color: markerBorder, width: 2),
            ),
            child: pending
                ? null
                : Center(
                    child: V2Icon(
                      state == V2TimelineState.done
                          ? V2IconName.check
                          : V2IconName.sprout,
                      size: V2Icons.small,
                      color: markerForeground,
                    ),
                  ),
          ),
          const SizedBox(width: V2Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: pending
                      ? V2Type.body.copyWith(color: V2Colors.muted)
                      : V2Type.bodyStrong,
                ),
                const SizedBox(height: V2Space.xs),
                Text(
                  subtitle,
                  style: V2Type.label.copyWith(color: V2Colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
