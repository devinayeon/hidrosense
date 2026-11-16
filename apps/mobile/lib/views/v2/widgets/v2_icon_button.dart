import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

enum V2IconButtonTone { plain, soft, filled }

/// Tombol ikon 48x48 dari component set `IconButton`.
class V2IconButton extends StatelessWidget {
  const V2IconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tone = V2IconButtonTone.plain,
    this.semanticLabel,
    this.size = 48,
  });

  final V2IconName icon;
  final VoidCallback? onPressed;
  final V2IconButtonTone tone;
  final String? semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      V2IconButtonTone.plain => (Colors.transparent, V2Colors.ink),
      V2IconButtonTone.soft => (V2Colors.blue50, V2Colors.blue700),
      V2IconButtonTone.filled => (V2Colors.blue500, V2Colors.white),
    };

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: V2Icon(icon, size: 24, color: foreground)),
          ),
        ),
      ),
    );
  }
}
