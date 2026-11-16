import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_button.dart';

/// Dialog dari component set `Dialog` (Type=Confirm).
class V2Dialog extends StatelessWidget {
  const V2Dialog({
    super.key,
    required this.title,
    this.body,
    this.primaryLabel = 'Simpan',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.child,
  });

  final String title;
  final String? body;
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
      ),
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
          V2Button(label: primaryLabel, onPressed: onPrimary),
          if (secondaryLabel != null) ...[
            const SizedBox(height: V2Space.md),
            V2Button(
              label: secondaryLabel!,
              type: V2ButtonType.tertiary,
              onPressed: onSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

/// Tampilkan [V2Dialog] sebagai modal dan kembalikan `true` bila aksi utama.
Future<bool?> showV2Dialog(
  BuildContext context, {
  required String title,
  String? body,
  String primaryLabel = 'Simpan',
  String? secondaryLabel,
  Widget? child,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: V2Colors.ink.withValues(alpha: 0.35),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(V2Space.xl),
      child: V2Dialog(
        title: title,
        body: body,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        child: child,
        onPrimary: () => Navigator.of(dialogContext).pop(true),
        onSecondary: () => Navigator.of(dialogContext).pop(false),
      ),
    ),
  );
}
