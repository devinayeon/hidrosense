import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_icon.dart';

/// Banner saran AI di page 09 (frame 9.14, 9.15, 9.19, 9.20).
///
/// Bentuk dan ukurannya sama dengan `Banner` shared, tetapi FigCraft memakai
/// teks serta ikon `#111827` (bukan biru) untuk nada AI di page ini. Karena
/// `V2Banner` dipakai halaman lain apa adanya, penyusun khusus halaman ini
/// dibuat di `components/` tanpa mengubah widget shared.
class V2RawatAiBanner extends StatelessWidget {
  const V2RawatAiBanner({
    super.key,
    this.message = 'Saran AI membantu. Keputusan tetap di tangan petani.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.blue50,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Row(
        children: [
          const V2Icon(V2IconName.care, color: V2Colors.ink),
          const SizedBox(width: V2Space.sm),
          Expanded(
            child: Text(
              message,
              style: V2Type.label.copyWith(color: V2Colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}