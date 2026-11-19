import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Nilai di atas batang 14/20 SemiBold. Token `V2Type` belum punya berat ini di
/// ukuran 14, jadi beratnya dinaikkan di komponen halaman ini saja.
final TextStyle _chartValueStyle = V2Type.label.copyWith(
  fontWeight: FontWeight.w600,
);

/// Satu batang grafik: label bulan, nilai teks, dan tinggi batang yang dipakai
/// relatif terhadap batang tertinggi.
class V2PenjualanChartBar {
  const V2PenjualanChartBar({
    required this.label,
    required this.value,
    required this.display,
  });

  final String label;
  final double value;

  /// Nilai yang ditulis di atas batang, mis. `5,2` (koma desimal).
  final String display;
}

/// Grafik penjualan bulanan (frame 8.5).
///
/// Kartu putih bersudut 24 dengan judul, tiga batang biru bertumpu pada garis
/// bawah, dan satu baris keterangan. Tinggi batang tertinggi 120, seperti
/// desain.
class V2PenjualanChartCard extends StatelessWidget {
  const V2PenjualanChartCard({
    super.key,
    required this.title,
    required this.bars,
    required this.caption,
  });

  final String title;
  final List<V2PenjualanChartBar> bars;
  final String caption;

  static const double _maxBarHeight = 120;

  @override
  Widget build(BuildContext context) {
    final maxValue = bars.fold<double>(0, (a, b) => b.value > a ? b.value : a);
    return Container(
      padding: const EdgeInsets.all(V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: V2Type.bodyStrong),
          const SizedBox(height: V2Space.sm),
          SizedBox(
            height: 168,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < bars.length; index++) ...[
                  if (index > 0) const SizedBox(width: V2Space.xl),
                  _Bar(
                    bar: bars[index],
                    height: maxValue == 0
                        ? 0
                        : bars[index].value / maxValue * _maxBarHeight,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: V2Space.sm),
          Text(caption, style: V2Type.label.copyWith(color: V2Colors.muted)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.bar, required this.height});

  final V2PenjualanChartBar bar;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(bar.display, style: _chartValueStyle),
          const SizedBox(height: V2Space.xs),
          Container(
            width: 64,
            height: height,
            decoration: const BoxDecoration(
              color: V2Colors.blue500,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
          const SizedBox(height: V2Space.xs),
          Text(bar.label, style: V2Type.label.copyWith(color: V2Colors.muted)),
        ],
      ),
    );
  }
}
