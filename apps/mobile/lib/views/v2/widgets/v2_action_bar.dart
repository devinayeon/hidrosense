import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_banner.dart';

/// Footer aksi yang dipaku di bawah konten (komponen `Actions` di FigCraft).
///
/// Dipakai halaman 08 (Penjualan) dan 11 (Sinkron). Susunannya dari atas: satu
/// [toast] opsional, satu [note] opsional (14/20 muted), lalu [actions]
/// bertumpuk. Jarak sesudah toast 16; jarak dari catatan ke tombol pertama 8.
/// Tanpa catatan, jarak antartombol 16 (frame 8.15/8.18); dengan catatan
/// semuanya rapat 8 (frame 8.17).
///
/// [safeBottom] memisahkan halaman ber-AppBar yang menyisakan ruang home
/// indicator (bawaan `true`) dari halaman yang sudah mendapatkannya dari
/// tempat lain, mis. saat keyboard terbuka (frame 8.10). Satu tombol diberi
/// sisa 8 di bawah sesuai desain; dua tombol atau lebih menempel tepat di atas
/// home indicator.
class V2ActionBar extends StatelessWidget {
  const V2ActionBar({
    super.key,
    this.note,
    this.actions = const <Widget>[],
    this.toast,
    this.toastTone = V2ToastTone.success,
    this.safeBottom = true,
  });

  final String? note;
  final List<Widget> actions;
  final String? toast;
  final V2ToastTone toastTone;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (toast != null) V2Toast(message: toast!, tone: toastTone),
      if (note != null)
        Text(note!, style: V2Type.label.copyWith(color: V2Colors.muted)),
      ...actions,
    ];

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(height: _gapBefore(index)),
          children[index],
        ],
      ],
    );

    final padding = EdgeInsets.fromLTRB(
      V2Space.xl,
      0,
      V2Space.xl,
      safeBottom ? (actions.length > 1 ? 0 : V2Space.sm) : 0,
    );

    return Container(
      color: V2Colors.canvas,
      child: safeBottom
          ? SafeArea(
              top: false,
              child: Padding(padding: padding, child: content),
            )
          : Padding(padding: padding, child: content),
    );
  }

  double _gapBefore(int index) {
    // Sesudah toast selalu 16 (frame 8.14, 8.16, 11.6).
    if (toast != null && index == 1) return V2Space.lg;
    // Catatan menempel tombolnya (frame 8.17, 11.4).
    if (note != null) return V2Space.sm;
    return V2Space.lg;
  }
}
