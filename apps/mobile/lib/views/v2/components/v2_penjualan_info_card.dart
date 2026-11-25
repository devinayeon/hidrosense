import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Satu baris kartu info: label kiri (14/20 muted) dan nilai kanan
/// (16/24 SemiBold).
class V2PenjualanInfoRow {
  const V2PenjualanInfoRow({required this.label, required this.value});

  final String label;
  final String value;
}

/// Kartu info tiga baris di bawah grafik (frame 8.5).
class V2PenjualanInfoCard extends StatelessWidget {
  const V2PenjualanInfoCard({super.key, required this.rows});

  final List<V2PenjualanInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.xl,
        vertical: V2Space.lg,
      ),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: V2Space.md),
            // `Wrap` supaya nilai yang panjang turun ke baris baru di skala teks
            // besar, bukan meluber keluar kartu (BUG-24).
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: V2Space.sm,
              runSpacing: V2Space.xs,
              children: [
                Text(
                  rows[index].label,
                  style: V2Type.label.copyWith(color: V2Colors.muted),
                ),
                Text(rows[index].value, style: V2Type.bodyStrong),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
