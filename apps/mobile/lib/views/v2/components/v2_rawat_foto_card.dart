import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_rawat_assets.dart';

/// Kartu biru “Cek hama” di puncak tab Rawat (frame 9.1).
///
/// Tinggi minimum 136: ilustrasi 88 di kotak biru muda bersudut 24, lalu teks
/// “Cek hama” 28/36 dan ajakan 14/20, keduanya putih. Tinggi minimum, bukan
/// tetap, supaya ajakan tidak terpotong pada skala teks besar (BUG-24).
class V2RawatCekHamaCard extends StatelessWidget {
  const V2RawatCekHamaCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 136),
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue500,
        borderRadius: BorderRadius.circular(V2Radius.sheet),
        boxShadow: V2Shadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: V2Colors.blue50,
              borderRadius: BorderRadius.circular(V2Radius.card),
            ),
            padding: const EdgeInsets.all(V2Space.sm),
            child: Image.asset(V2RawatAssets.itemPlantCare),
          ),
          const SizedBox(width: V2Space.lg),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cek hama',
                  style: V2Type.value.copyWith(color: V2Colors.white),
                ),
                Text(
                  'Foto daun, AI bantu cari hama.',
                  style: V2Type.label.copyWith(color: V2Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(V2Radius.sheet),
        child: content,
      ),
    );
  }
}

/// Kartu abu “Foto tanaman” berisi foto contoh (frame 9.9–9.12, 9.14–9.16,
/// 9.24–9.27).
///
/// [height] mengikuti frame: 140 (hasil), 160 (detail), 200 (tanpa internet),
/// atau 240 (pratinjau dan unggah). Gambar 96 dan keterangan 14/20 diletakkan
/// di tengah secara vertikal.
class V2RawatFotoCard extends StatelessWidget {
  const V2RawatFotoCard({
    super.key,
    required this.height,
    this.caption = 'Foto contoh',
  });

  final double height;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(vertical: V2Space.sm),
      decoration: BoxDecoration(
        color: V2Colors.gray200,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              V2RawatAssets.harvestLettuce,
              width: 96,
              height: 96,
            ),
            const SizedBox(height: V2Space.sm),
            Text(
              caption,
              style: V2Type.label.copyWith(color: V2Colors.slate600),
            ),
          ],
        ),
      ),
    );
  }
}