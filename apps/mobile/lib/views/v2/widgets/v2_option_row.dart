import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

enum V2OptionState { normal, selected, pressed, disabled }

/// Baris pilihan dari component set `OptionRow` (dipakai bottom sheet).
class V2OptionRow extends StatelessWidget {
  const V2OptionRow({
    super.key,
    required this.label,
    this.state = V2OptionState.normal,
    this.onTap,
  });

  final String label;
  final V2OptionState state;
  final VoidCallback? onTap;

  bool get _selected => state == V2OptionState.selected;
  bool get _disabled => state == V2OptionState.disabled;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: V2Space.lg, right: V2Space.xl),
      decoration: BoxDecoration(
        color: _disabled
            ? V2Colors.gray200
            : _selected
            ? V2Colors.blue50
            : V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        border: Border.all(
          color: _selected || state == V2OptionState.pressed
              ? V2Colors.blue700
              : V2Colors.slate400,
          width: _selected ? 3 : 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V2Type.bodyStrong.copyWith(
                color: _disabled ? V2Colors.muted : V2Colors.ink,
              ),
            ),
          ),
          const SizedBox(width: V2Space.md),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _selected ? V2Colors.blue500 : V2Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: _selected ? V2Colors.blue500 : V2Colors.slate400,
                width: 2,
              ),
            ),
            child: _selected
                ? const V2Icon(
                    V2IconName.check,
                    size: 18,
                    color: V2Colors.white,
                  )
                : null,
          ),
        ],
      ),
    );

    if (_disabled || onTap == null) return content;
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
