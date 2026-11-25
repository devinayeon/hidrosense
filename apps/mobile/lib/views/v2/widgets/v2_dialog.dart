import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_button.dart';

/// Varian dialog: `Confirm` (aksi utama biru) dan `Destructive` (aksi utama
/// merah, dipakai konfirmasi nonaktifkan).
enum V2DialogType { confirm, destructive }

/// Dialog dari component set `Dialog` (Type=Confirm/Destructive).
class V2Dialog extends StatelessWidget {
  const V2Dialog({
    super.key,
    required this.title,
    this.body,
    this.type = V2DialogType.confirm,
    this.primaryLabel = 'Simpan',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.child,
  });

  final String title;
  final String? body;
  final V2DialogType type;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.sheet),
        boxShadow: V2Shadow.card,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: V2Type.h2),
            if (body != null) ...[
              const SizedBox(height: V2Space.lg),
              Text(body!, style: V2Type.body.copyWith(color: V2Colors.muted)),
            ],
            if (child != null) ...[const SizedBox(height: V2Space.lg), child!],
            const SizedBox(height: V2Space.lg),
            V2Button(
              label: primaryLabel,
              type: type == V2DialogType.destructive
                  ? V2ButtonType.destructive
                  : V2ButtonType.primary,
              onPressed: onPrimary,
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: V2Space.lg),
              V2Button(
                label: secondaryLabel!,
                type: V2ButtonType.tertiary,
                onPressed: onSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tampilkan [V2Dialog] sebagai modal dan kembalikan `true` bila aksi utama.
Future<bool?> showV2Dialog(
  BuildContext context, {
  required String title,
  String? body,
  V2DialogType type = V2DialogType.confirm,
  String primaryLabel = 'Simpan',
  String? secondaryLabel,
  Widget? child,
}) {
  return showDialog<bool>(
    context: context,
    // FigCraft menggambar Scrim `#111827` 60% dan menaruh dialog di tengah
    // frame penuh (3.3, 3.9, 3.13, 3.15, 11.8), bukan di tengah area aman.
    barrierColor: V2Colors.ink.withValues(alpha: 0.6),
    useSafeArea: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(V2Space.xl),
      child: V2Dialog(
        title: title,
        body: body,
        type: type,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        child: child,
        onPrimary: () => Navigator.of(dialogContext).pop(true),
        onSecondary: () => Navigator.of(dialogContext).pop(false),
      ),
    ),
  );
}
