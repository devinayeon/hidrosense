import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Kartu `Grup daftar` yang dipakai halaman 08 (Penjualan) dan 11 (Sinkron).
///
/// Putih, sudut 24, `Shadow/Card`. Anak-anaknya dipisah garis 1px `#E5E8EC`
/// yang menjorok [dividerIndent] dari kiri dan kanan, supaya garisnya mulai di
/// ujung kiri teks baris (bukan di bawah ikon) dan berhenti di ujung kanan
/// kolom nilai.
///
/// Baris di dalamnya sebaiknya memakai `V2StockItem(withCard: false, ...)`
/// supaya tidak ada kartu putih bertumpuk di dalam kartu ini.
class V2GroupList extends StatelessWidget {
  const V2GroupList({
    super.key,
    required this.children,
    this.dividerIndent = 76,
    this.elevated = true,
  });

  final List<Widget> children;
  final double dividerIndent;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: elevated ? V2Shadow.card : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: dividerIndent,
                endIndent: dividerIndent,
                color: V2Colors.border,
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}
