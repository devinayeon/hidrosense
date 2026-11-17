import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Kartu `Type=Tint` di form catat/ubah penjualan (frame 8.7, 8.8, 8.10–8.13,
/// 8.21, 8.23, 8.24, dan 11.9).
///
/// Tanpa kartu putih: latar biru muda `#EAF2FF`, sudut 24, padding 24, jarak 8
/// antara judul dan nilai. Tinggi minimum 120 seperti desain, supaya kartu
/// tidak menyusut saat nilainya masih kosong.
class V2PenjualanTintCard extends StatelessWidget {
  const V2PenjualanTintCard({
    super.key,
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue50,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: V2Type.label.copyWith(color: V2Colors.slate600),
          ),
          const SizedBox(height: V2Space.sm),
          Text(value, style: V2Type.value),
        ],
      ),
    );
  }
}
