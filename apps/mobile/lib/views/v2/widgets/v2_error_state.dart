import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_button.dart';
import 'v2_icon.dart';

/// Kondisi kosong/gagal dari component `ErrorState`.
///
/// FigCraft memakai ilustrasi vektor 160px; di aplikasi slot ilustrasi bisa
/// diisi asset yang sudah ada. Bila kosong, dipakai medali ikon cloud.
class V2ErrorState extends StatelessWidget {
  const V2ErrorState({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.illustration,
    this.icon = V2IconName.cloud,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? illustration;
  final V2IconName icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        illustration ??
            Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                color: V2Colors.blue50,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: V2Icon(icon, size: 64, color: V2Colors.blue500),
              ),
            ),
        const SizedBox(height: V2Space.lg),
        Text(title, textAlign: TextAlign.center, style: V2Type.h2),
        const SizedBox(height: V2Space.sm),
        Text(
          body,
          textAlign: TextAlign.center,
          style: V2Type.body.copyWith(color: V2Colors.muted),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: V2Space.lg),
          V2Button(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );
  }
}

/// Catatan alur di atas tiap halaman fitur (component `FlowNote`).
class V2FlowNote extends StatelessWidget {
  const V2FlowNote({
    super.key,
    required this.title,
    required this.note,
    this.roleLabel,
  });

  final String title;
  final String note;
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue50,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: V2Type.h1),
          const SizedBox(height: V2Space.sm),
          Text(note, style: V2Type.body.copyWith(color: V2Colors.slate600)),
          if (roleLabel != null) ...[
            const SizedBox(height: V2Space.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: V2Space.lg,
                  vertical: V2Space.xs,
                ),
                decoration: BoxDecoration(
                  color: V2Colors.gray200,
                  borderRadius: BorderRadius.circular(V2Radius.pill),
                ),
                child: Text(
                  roleLabel!,
                  style: V2Type.label.copyWith(color: V2Colors.slate600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
