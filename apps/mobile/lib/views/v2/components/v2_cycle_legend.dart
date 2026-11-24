import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Keterangan garis penanda HSS di halaman detail siklus (frame 2.7).
///
/// Contoh teks: "Garis: HSS 15, pindah ke meja".
class V2CycleLegend extends StatelessWidget {
  const V2CycleLegend({
    super.key,
    this.label = 'Garis: HSS 15, pindah ke meja',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: V2Colors.ink,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: V2Space.sm),
        // Label boleh membungkus; tanpa `Flexible` baris ini meluber keluar
        // layar pada skala teks besar (BUG-24).
        Flexible(
          child: Text(
            label,
            style: V2Type.label.copyWith(color: V2Colors.muted),
          ),
        ),
      ],
    );
  }
}
