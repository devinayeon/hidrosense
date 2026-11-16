import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

enum V2TimelineState { done, active, pending }

/// Satu langkah linimasa dari component set `TimelineStep`.
class V2TimelineStep extends StatelessWidget {
  const V2TimelineStep({
    super.key,
    required this.title,
    required this.subtitle,
    this.state = V2TimelineState.pending,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final V2TimelineState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (markerBackground, markerForeground) = switch (state) {
      V2TimelineState.done => (V2Colors.green100, V2Colors.green700),
      V2TimelineState.active => (V2Colors.blue50, V2Colors.blue500),
      V2TimelineState.pending => (V2Colors.gray200, V2Colors.slate400),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: markerBackground,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: state == V2TimelineState.pending
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: markerForeground,
                          shape: BoxShape.circle,
                        ),
                      )
                    : V2Icon(
                        V2IconName.check,
                        size: 16,
                        color: markerForeground,
                      ),
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 24, color: V2Colors.border),
          ],
        ),
        const SizedBox(width: V2Space.lg),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: V2Space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: V2Type.bodyStrong),
                const SizedBox(height: V2Space.xs),
                Text(
                  subtitle,
                  style: V2Type.label.copyWith(color: V2Colors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
