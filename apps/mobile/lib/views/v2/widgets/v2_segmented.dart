import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Segmented control dari `Segmented` (2 segmen) dan `Segmented3` (3 segmen).
class V2Segmented extends StatelessWidget {
  const V2Segmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(V2Space.xs),
      decoration: BoxDecoration(
        color: V2Colors.gray200,
        borderRadius: BorderRadius.circular(V2Radius.pill),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: _Segment(
                label: labels[index],
                selected: index == selectedIndex,
                onTap: onChanged == null ? null : () => onChanged!(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? V2Colors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(V2Radius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: V2Type.bodyStrong.copyWith(
          color: selected ? V2Colors.white : V2Colors.slate600,
        ),
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        child: content,
      ),
    );
  }
}
