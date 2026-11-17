import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Satu baris label/nilai di [V2AkunInfoCard].
class V2AkunInfoRow {
  const V2AkunInfoRow({required this.label, required this.value});

  final String label;
  final String value;
}

/// Kartu data akun dari frame 3.2, 3.11, dan 3.17 (komponen `Info`).
///
/// Putih, sudut 24, `Shadow/Card`, padding 24, jarak antar baris 16. Tiap baris
/// berisi label 14/20 Medium muted di atas nilai 16/24 Regular ink.
class V2AkunInfoCard extends StatelessWidget {
  const V2AkunInfoCard({super.key, required this.rows});

  final List<V2AkunInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: V2Space.lg),
            Text(
              rows[index].label,
              style: V2Type.label.copyWith(color: V2Colors.muted),
            ),
            Text(rows[index].value, style: V2Type.body),
          ],
        ],
      ),
    );
  }
}
