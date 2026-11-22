import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

/// Stepper bulat dari component set `Stepper` (48px).
class V2Stepper extends StatelessWidget {
  const V2Stepper({
    super.key,
    required this.value,
    this.onMinus,
    this.onPlus,
    this.enabled = true,
  });

  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundAction(icon: V2IconName.minus, onTap: enabled ? onMinus : null),
        const SizedBox(width: V2Space.lg),
        SizedBox(
          width: 56,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: V2Type.h2.copyWith(
              color: enabled ? V2Colors.ink : V2Colors.muted,
            ),
          ),
        ),
        const SizedBox(width: V2Space.lg),
        _RoundAction(icon: V2IconName.plus, onTap: enabled ? onPlus : null),
      ],
    );
  }
}

/// Field jumlah dengan tombol minus/plus 56px dari component set `Qty`.
///
/// Angka selalu abu ([V2Colors.muted]) kecuali saat [error], mengikuti state
/// `Qty`: Default/Focus abu, Error ink. [error] juga menyalakan border merah 3px
/// (frame 4.22 "Stok kurang"). Baris pesan galat tidak digambar di sini karena
/// di desain `Helper` berdiri sebagai saudara `Qty`, bukan di dalamnya.
class V2QtyField extends StatelessWidget {
  const V2QtyField({
    super.key,
    required this.value,
    this.unit = '',
    this.onMinus,
    this.onPlus,
    this.enabled = true,
    this.error = false,
  });

  final int value;
  final String unit;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final bool enabled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundAction(
          icon: V2IconName.minus,
          size: 56,
          onTap: enabled ? onMinus : null,
        ),
        const SizedBox(width: V2Space.sm),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: V2Space.md),
            decoration: BoxDecoration(
              color: enabled ? V2Colors.white : V2Colors.gray200,
              borderRadius: BorderRadius.circular(V2Radius.pill),
              border: Border.all(
                color: error ? V2Colors.red700 : V2Colors.slate400,
                width: error ? 3 : 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    '$value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2Type.bodyStrong.copyWith(
                      // Angka abu saat biasa, jadi ink saat galat (component `Qty`).
                      color: error ? V2Colors.ink : V2Colors.muted,
                    ),
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: V2Space.sm),
                  Flexible(
                    child: Text(
                      unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V2Type.body.copyWith(color: V2Colors.muted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: V2Space.sm),
        _RoundAction(
          icon: V2IconName.plus,
          size: 56,
          onTap: enabled ? onPlus : null,
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, this.size = 48, this.onTap});

  final V2IconName icon;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onTap == null ? V2Colors.gray200 : V2Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: onTap == null ? V2Colors.gray200 : V2Colors.slate400,
          width: 2,
        ),
      ),
      child: Center(
        child: V2Icon(
          icon,
          size: size >= 56 ? 24 : 24,
          color: onTap == null ? V2Colors.muted : V2Colors.ink,
        ),
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: content,
      ),
    );
  }
}
