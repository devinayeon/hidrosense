import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

/// Input dari component set `Input` dan `InputPassword`.
///
/// State default, focus, filled, error, dan disabled mengikuti FigCraft.
class V2TextField extends StatefulWidget {
  const V2TextField({
    super.key,
    required this.label,
    this.hint = '',
    this.controller,
    this.helper,
    this.error,
    this.enabled = true,
    this.forceFocus = false,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? helper;
  final String? error;
  final bool enabled;

  /// Untuk pratinjau state Focus di halaman review.
  final bool forceFocus;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;

  @override
  State<V2TextField> createState() => _V2TextFieldState();
}

class _V2TextFieldState extends State<V2TextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  bool get _focused => widget.forceFocus || _focusNode.hasFocus;
  bool get _hasError => widget.error != null && widget.error!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final borderColor = _hasError
        ? V2Colors.red700
        : _focused
        ? V2Colors.blue500
        : V2Colors.slate400;
    final borderWidth = _focused || _hasError ? 3.0 : 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: V2Type.label.copyWith(
            color: widget.enabled ? V2Colors.muted : V2Colors.slate400,
          ),
        ),
        const SizedBox(height: V2Space.sm),
        Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.only(left: V2Space.xl, right: V2Space.md),
          decoration: BoxDecoration(
            color: widget.enabled ? V2Colors.white : V2Colors.gray200,
            borderRadius: BorderRadius.circular(V2Radius.pill),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Row(
            children: [
              Expanded(
                // Kursor dan sorotan seleksi diambil dari DefaultSelectionStyle
                // yang dibuat MaterialApp dari theme lama (teal), bukan dari
                // Theme v2 terdekat, jadi keduanya di-set ulang di sini.
                child: DefaultSelectionStyle(
                  cursorColor: V2Colors.blue500,
                  selectionColor: V2Colors.blue500.withValues(alpha: 0.4),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    obscureText: widget.obscure,
                    keyboardType: widget.keyboardType,
                    style: V2Type.body.copyWith(
                      color: widget.enabled ? V2Colors.ink : V2Colors.muted,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: V2Type.body.copyWith(color: V2Colors.muted),
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: V2Space.sm),
                widget.trailing!,
              ],
            ],
          ),
        ),
        if (_hasError) ...[
          const SizedBox(height: V2Space.sm),
          Row(
            children: [
              const V2Icon(
                V2IconName.warning,
                size: V2Icons.small,
                color: V2Colors.red700,
              ),
              const SizedBox(width: V2Space.sm),
              Expanded(
                child: Text(
                  widget.error!,
                  style: V2Type.label.copyWith(color: V2Colors.red700),
                ),
              ),
            ],
          ),
        ] else if (widget.helper != null) ...[
          const SizedBox(height: V2Space.sm),
          Text(
            widget.helper!,
            style: V2Type.label.copyWith(color: V2Colors.muted),
          ),
        ],
      ],
    );
  }
}

/// Input password dengan tombol "Tampilkan".
class V2PasswordField extends StatefulWidget {
  const V2PasswordField({
    super.key,
    this.label = 'Password',
    this.hint = 'Ketik password',
    this.controller,
    this.error,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? error;
  final bool enabled;

  @override
  State<V2PasswordField> createState() => _V2PasswordFieldState();
}

class _V2PasswordFieldState extends State<V2PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return V2TextField(
      label: widget.label,
      hint: widget.hint,
      controller: widget.controller,
      error: widget.error,
      enabled: widget.enabled,
      obscure: !_visible,
      trailing: TextButton(
        onPressed: widget.enabled
            ? () => setState(() => _visible = !_visible)
            : null,
        style: TextButton.styleFrom(
          foregroundColor: V2Colors.blue700,
          padding: const EdgeInsets.symmetric(horizontal: V2Space.sm),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          _visible ? 'Sembunyikan' : 'Tampilkan',
          style: V2Type.label.copyWith(
            color: widget.enabled ? V2Colors.blue700 : V2Colors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
