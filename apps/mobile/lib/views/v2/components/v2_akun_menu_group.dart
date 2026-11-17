import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Grup daftar pada frame 3.1, 3.2, 3.5, 3.10, dan 3.16 (komponen `Grup daftar`).
///
/// Kartu putih sudut 24 dengan `Shadow/Card`; anak-anaknya dipisah garis 1px
/// `#E5E8EC` yang menjorok 76 dari kiri supaya sejajar dengan ujung kiri judul
/// baris, bukan ikon.
///
/// Baris yang berdiri sendiri di frame 3.2 memakai `elevated: false`: pada
/// acuan FigCraft baris itu bersudut 24 tetapi tanpa bayangan, karena bukan
/// bagian dari `Grup daftar`.
class V2AkunMenuGroup extends StatelessWidget {
  const V2AkunMenuGroup({
    super.key,
    required this.children,
    this.indent = 76,
    this.elevated = true,
  });

  final List<Widget> children;
  final double indent;
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
                indent: indent,
                color: V2Colors.border,
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}
