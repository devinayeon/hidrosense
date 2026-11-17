import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Label kelompok di dalam daftar (frame 2.4: "Baru", "Sebelumnya").
///
/// Dipakai sebagai pemisah antar kelompok `V2ListItem`; jarak antar anak daftar
/// diatur pemanggil.
class V2GroupLabel extends StatelessWidget {
  const V2GroupLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: V2Type.label.copyWith(color: V2Colors.muted));
  }
}
