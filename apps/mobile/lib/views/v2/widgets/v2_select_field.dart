import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

/// Select dari component set `Select` (label + field + ikon kanan).
///
/// [icon] bawaan chevron-down; pemilih tanggal memakai `V2IconName.calendar`.
/// [error] menyalakan border merah 3px plus baris pesan ber-ikon, mengikuti
/// pola yang sama dengan `V2TextField`.
class V2SelectField extends StatelessWidget {
  const V2SelectField({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.onTap,
    this.enabled = true,
    this.error,
    this.helper,
    this.icon = V2IconName.chevronDown,
  });

  final String label;
  final String? value;
  final String? hint;
  final VoidCallback? onTap;
  final bool enabled;
  final String? error;
  final String? helper;
  final V2IconName icon;

  bool get _hasError => error != null && error!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final showHint = value == null || value!.isEmpty;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: V2Space.xl, right: V2Space.lg),
      decoration: BoxDecoration(
        color: enabled ? V2Colors.white : V2Colors.gray200,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        border: Border.all(
          color: _hasError
              ? V2Colors.red700
              : V2Colors.slate400,
          width: _hasError ? 3 : 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              showHint ? (hint ?? 'Pilih') : value!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V2Type.body.copyWith(
                color: showHint || !enabled ? V2Colors.muted : V2Colors.ink,
              ),
            ),
          ),
          const SizedBox(width: V2Space.sm),
          V2Icon(
            icon,
            color: enabled ? V2Colors.ink : V2Colors.slate400,
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: V2Type.label.copyWith(
            color: enabled ? V2Colors.muted : V2Colors.slate400,
          ),
        ),
        const SizedBox(height: V2Space.sm),
        if (onTap == null || !enabled)
          content
        else
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(V2Radius.pill),
              child: content,
            ),
          ),
        if (_hasError) ...[
          const SizedBox(height: V2Space.sm),
          Row(
            children: [
              const V2Icon(
                V2IconName.close,
                size: V2Icons.small,
                color: V2Colors.red700,
              ),
              const SizedBox(width: V2Space.sm),
              Expanded(
                child: Text(
                  error!,
                  style: V2Type.label.copyWith(color: V2Colors.red700),
                ),
              ),
            ],
          ),
        ] else if (helper != null) ...[
          const SizedBox(height: V2Space.sm),
          Text(
            helper!,
            style: V2Type.label.copyWith(color: V2Colors.muted),
          ),
        ],
      ],
    );
  }
}

/// Search field dari component `SearchField`.
class V2SearchField extends StatelessWidget {
  const V2SearchField({
    super.key,
    this.hint = 'Cari stok',
    this.controller,
    this.onChanged,
    this.onClear,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        border: Border.all(color: V2Colors.slate400, width: 2),
      ),
      child: Row(
        children: [
          const V2Icon(V2IconName.search, color: V2Colors.muted),
          const SizedBox(width: V2Space.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: V2Type.body,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: V2Type.body.copyWith(color: V2Colors.muted),
              ),
            ),
          ),
          if (controller != null && controller!.text.isNotEmpty)
            IconButton(
              onPressed: onClear,
              icon: const V2Icon(V2IconName.close, color: V2Colors.ink),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
