import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Kerangka bottom sheet dari `BottomSheet`, `Sheet/Pilih`, `Sheet/CatatStok`,
/// dan `Sheet/Tanggal`: sudut atas 32, handle 36x5, padding 24.
class V2BottomSheet extends StatelessWidget {
  const V2BottomSheet({
    super.key,
    this.title,
    this.child,
    this.actions,
    this.flexible = false,
  });

  final String? title;
  final Widget? child;
  final Widget? actions;

  /// Bila true, [child] mengisi sisa tinggi sheet (mis. untuk daftar yang
  /// digulir). Sheet perlu dibatasi tingginya oleh pemanggil agar tidak
  /// meluber ke luar layar.
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        V2Space.xl,
        V2Space.xl,
        V2Space.xl,
        V2Space.xl,
      ),
      decoration: const BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(V2Radius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: V2Colors.slate400,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            if (title != null) ...[
              // Semua komponen `Sheet/*` di Foundations memakai jarak 16
              // setelah handle (judul duduk di y=45 dari atas sheet).
              const SizedBox(height: V2Space.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(title!, style: V2Type.h2),
              ),
            ],
            if (child != null) ...[
              const SizedBox(height: V2Space.lg),
              if (flexible) Flexible(child: child!) else child!,
            ],
            if (actions != null) ...[
              const SizedBox(height: V2Space.lg),
              actions!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Tampilkan [V2BottomSheet] dari bawah dengan latar gelap transparan.
Future<T?> showV2BottomSheet<T>(BuildContext context, {required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: V2Colors.ink.withValues(alpha: 0.6),
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    ),
  );
}
