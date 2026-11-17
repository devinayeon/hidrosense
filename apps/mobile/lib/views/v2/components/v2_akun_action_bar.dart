import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_banner.dart';

/// Footer aksi yang dipaku di bawah konten (komponen `Actions` di FigCraft).
///
/// Menampung satu atau dua tombol bertumpuk dengan jarak 16, dan opsional satu
/// toast yang melayang 16 di atas tombol (frame 3.10, 3.14, 3.16).
/// [safeBottom] membedakan dua keluarga bingkai: halaman ber-AppBar menyisakan
/// ruang home indicator, sedangkan tab shell sudah mendapatkannya dari TabBar.
class V2AkunActionBar extends StatelessWidget {
  const V2AkunActionBar({
    super.key,
    this.actions = const <Widget>[],
    this.toast,
    this.toastTone = V2ToastTone.success,
    this.safeBottom = false,
  });

  final List<Widget> actions;
  final String? toast;
  final V2ToastTone toastTone;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (toast != null) ...[
          V2Toast(message: toast!, tone: toastTone),
          const SizedBox(height: V2Space.lg),
        ],
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(height: V2Space.lg),
          actions[index],
        ],
      ],
    );

    if (!safeBottom) {
      return Container(
        color: V2Colors.canvas,
        padding: const EdgeInsets.fromLTRB(
          V2Space.xl,
          0,
          V2Space.xl,
          V2Space.xl,
        ),
        child: content,
      );
    }
    return Container(
      color: V2Colors.canvas,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            V2Space.xl,
            0,
            V2Space.xl,
            V2Space.sm,
          ),
          child: content,
        ),
      ),
    );
  }
}
