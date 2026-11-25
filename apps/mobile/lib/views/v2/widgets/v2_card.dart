import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

enum V2CardTone { plain, soft, brand, bone }

/// Kartu permukaan dari component set `Card`.
class V2Card extends StatelessWidget {
  const V2Card({
    super.key,
    this.title,
    this.body,
    this.child,
    this.tone = V2CardTone.plain,
    this.padding = const EdgeInsets.all(V2Space.xl),
    this.onTap,
  });

  final String? title;
  final String? body;
  final Widget? child;
  final V2CardTone tone;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  Color get _background => switch (tone) {
    V2CardTone.plain => V2Colors.white,
    V2CardTone.soft => V2Colors.blue50,
    V2CardTone.brand => V2Colors.blue500,
    V2CardTone.bone => V2Colors.bone,
  };

  Color get _titleColor =>
      tone == V2CardTone.brand ? V2Colors.white : V2Colors.ink;

  Color get _bodyColor =>
      tone == V2CardTone.brand ? V2Colors.white : V2Colors.muted;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: tone == V2CardTone.plain ? V2Shadow.card : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Text(title!, style: V2Type.h2.copyWith(color: _titleColor)),
          if (title != null && (body != null || child != null))
            const SizedBox(height: V2Space.sm),
          if (body != null)
            Text(body!, style: V2Type.body.copyWith(color: _bodyColor)),
          if (body != null && child != null) const SizedBox(height: V2Space.md),
          ?child,
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(V2Radius.card),
        child: content,
      ),
    );
  }
}
