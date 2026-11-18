import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_panen_data.dart';

/// Kartu grafik “Berat layak per panen (kg)” (frame 7.6).
///
/// Kartu putih 342×240: padding 16, judul 16/24 SemiBold, bidang grafik 128,
/// lalu keterangan 14/20 muted dua baris. Batang biru 48 lebar, bersudut 4 di
/// atas, dengan nilai dan label tanggal 14/20.
class V2PanenChartCard extends StatelessWidget {
  const V2PanenChartCard({
    super.key,
    required this.bars,
    required this.caption,
  });

  final List<V2PanenGrafikBatang> bars;
  final String caption;

  static const double _maxBarHeight = 80;

  @override
  Widget build(BuildContext context) {
    final maxBerat = bars.fold<double>(
      0,
      (tertinggi, bar) => bar.berat > tertinggi ? bar.berat : tertinggi,
    );

    return Container(
      padding: const EdgeInsets.all(V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Berat layak per panen (kg)', style: V2Type.bodyStrong),
          const SizedBox(height: V2Space.sm),
          SizedBox(
            height: 128,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < bars.length; index++) ...[
                  if (index > 0) const SizedBox(width: V2Space.xl),
                  _Batang(
                    bar: bars[index],
                    tinggi: maxBerat == 0
                        ? 0
                        : bars[index].berat / maxBerat * _maxBarHeight,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: V2Space.sm),
          Text(
            caption,
            style: V2Type.label.copyWith(color: V2Colors.muted),
          ),
        ],
      ),
    );
  }
}

class _Batang extends StatelessWidget {
  const _Batang({required this.bar, required this.tinggi});

  final V2PanenGrafikBatang bar;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(bar.display, style: V2Type.label.copyWith(
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: V2Space.xs),
          Container(
            width: 48,
            height: tinggi,
            decoration: const BoxDecoration(
              color: V2Colors.blue500,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
          const SizedBox(height: V2Space.xs),
          Text(
            bar.label,
            style: V2Type.label.copyWith(color: V2Colors.muted),
          ),
        ],
      ),
    );
  }
}