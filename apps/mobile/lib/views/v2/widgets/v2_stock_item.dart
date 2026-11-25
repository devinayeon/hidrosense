import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

/// Nada warna lingkaran lead pada [V2StockItem].
enum V2StockItemTone { blue, warning, neutral }

/// Baris stok dari component set `StockItem` (lead 40, qty di kanan).
///
/// Bawaan [withCard] `true` menggambar baris sebagai kartu putih bersudut 24
/// seperti di galeri `00 Foundations`. Di dalam `Grup daftar` (halaman 08 dan
/// 11) [withCard] diisi `false` supaya latar dan pemisahnya diurus oleh
/// `V2GroupList`; baris di grup itu memakai lead 24 dan padding vertikal 20
/// sehingga tingginya 80.
class V2StockItem extends StatelessWidget {
  const V2StockItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.quantity,
    this.icon = V2IconName.sprout,
    this.badge,
    this.onTap,
    this.divider = false,
    this.withCard = true,
    this.tone = V2StockItemTone.blue,
    this.iconSize = 22,
    this.contentPadding,
  });

  final String title;
  final String subtitle;
  final String quantity;
  final V2IconName icon;
  final Widget? badge;
  final VoidCallback? onTap;
  final bool divider;
  final bool withCard;
  final V2StockItemTone tone;
  final double iconSize;
  final EdgeInsetsGeometry? contentPadding;

  (Color, Color) get _lead => switch (tone) {
    V2StockItemTone.blue => (V2Colors.blue50, V2Colors.blue700),
    V2StockItemTone.warning => (V2Colors.amber100, V2Colors.amber800),
    V2StockItemTone.neutral => (V2Colors.gray200, V2Colors.slate600),
  };

  @override
  Widget build(BuildContext context) {
    final (leadBackground, leadColor) = _lead;
    final content = Padding(
      padding:
          contentPadding ??
          const EdgeInsets.symmetric(
            horizontal: V2Space.lg,
            vertical: V2Space.md,
          ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: leadBackground,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: V2Icon(icon, size: iconSize, color: leadColor),
              ),
            ),
            const SizedBox(width: V2Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2Type.bodyStrong,
                  ),
                  const SizedBox(height: V2Space.xs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2Type.label.copyWith(color: V2Colors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: V2Space.md),
            // Kolom kanan (jumlah + lencana) dibatasi separuh lebar baris supaya
            // judul di kiri tetap punya ruang; selebihnya teks membungkus atau
            // dipotong, tidak meluap.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.hasBoundedWidth
                    ? constraints.maxWidth * 0.55
                    : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    quantity,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: V2Type.bodyStrong,
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: V2Space.xs),
                    badge!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final wrapped = InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          if (divider)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: V2Space.lg),
              child: Divider(height: 1),
            ),
        ],
      ),
    );

    if (!withCard) return onTap == null ? content : wrapped;

    return Container(
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : wrapped,
    );
  }
}
