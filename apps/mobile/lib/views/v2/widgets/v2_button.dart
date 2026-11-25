import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

enum V2ButtonType { primary, secondary, tertiary, destructive, ghost }

enum V2ButtonState { normal, pressed, disabled, focus, loading }

/// Tombol dari component set `Button` (5 tipe x 5 state).
class V2Button extends StatelessWidget {
  const V2Button({
    super.key,
    required this.label,
    this.onPressed,
    this.type = V2ButtonType.primary,
    V2ButtonState state = V2ButtonState.normal,
    bool loading = false,
    this.icon,
    this.expand = true,
  }) : state = loading ? V2ButtonState.loading : state;

  final String label;
  final VoidCallback? onPressed;
  final V2ButtonType type;
  final V2ButtonState state;
  final V2IconName? icon;
  final bool expand;

  bool get _disabled =>
      state == V2ButtonState.disabled ||
      (onPressed == null && state != V2ButtonState.loading);

  Color get _background => switch (type) {
    V2ButtonType.primary => switch (state) {
      V2ButtonState.pressed => V2Colors.blue600,
      V2ButtonState.disabled => V2Colors.gray200,
      _ => V2Colors.blue500,
    },
    V2ButtonType.secondary => switch (state) {
      V2ButtonState.disabled => V2Colors.gray200,
      _ => V2Colors.lime400,
    },
    V2ButtonType.tertiary => switch (state) {
      V2ButtonState.pressed => V2Colors.blue50,
      V2ButtonState.disabled => V2Colors.gray200,
      _ => V2Colors.white,
    },
    V2ButtonType.destructive => switch (state) {
      V2ButtonState.pressed => V2Colors.red800,
      V2ButtonState.disabled => V2Colors.gray200,
      _ => V2Colors.red700,
    },
    V2ButtonType.ghost => Colors.transparent,
  };

  Color get _foreground => state == V2ButtonState.disabled
      ? V2Colors.slate400
      : switch (type) {
          V2ButtonType.primary || V2ButtonType.destructive => V2Colors.white,
          V2ButtonType.secondary || V2ButtonType.tertiary => V2Colors.ink,
          V2ButtonType.ghost => V2Colors.blue500,
        };

  Color get _border => switch (type) {
    V2ButtonType.tertiary => V2Colors.slate400,
    V2ButtonType.primary || V2ButtonType.secondary
        when state == V2ButtonState.focus =>
      V2Colors.blue700,
    V2ButtonType.primary || V2ButtonType.secondary
        when state == V2ButtonState.pressed =>
      V2Colors.blue700,
    _ => Colors.transparent,
  };

  double get _stroke => switch (state) {
    V2ButtonState.focus => 3,
    V2ButtonState.pressed => 2,
    _ => type == V2ButtonType.tertiary ? 2 : 0,
  };

  double get _height => type == V2ButtonType.ghost ? 48 : 56;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state == V2ButtonState.loading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_foreground),
            ),
          ),
          const SizedBox(width: V2Space.sm),
        ] else if (icon != null) ...[
          V2Icon(icon!, size: 20, color: _foreground),
          const SizedBox(width: V2Space.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V2Type.button.copyWith(color: _foreground),
          ),
        ),
      ],
    );

    final button = Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        border: _stroke == 0
            ? null
            : Border.all(color: _border, width: _stroke),
        // Lip 2px hanya milik `Type=Primary` (component set Button di
        // Foundations); Secondary/Destructive tidak punya bayangan.
        boxShadow: state == V2ButtonState.normal && type == V2ButtonType.primary
            ? V2Shadow.buttonLip
            : null,
      ),
      child: content,
    );

    final tappable = _disabled || state == V2ButtonState.loading
        ? button
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(V2Radius.pill),
              child: button,
            ),
          );

    return Semantics(
      button: true,
      enabled: !_disabled,
      child: SizedBox(width: expand ? double.infinity : null, child: tappable),
    );
  }
}
