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
    // Label bulan diletakkan di baris terpisah yang lebarnya sama dengan slot
    // batang. Kalau label ikut di dalam kolom batang, teks yang membesar di
    // skala 2.0 menggeser garis dasar dan label tidak sejajar dengan grafiknya
    // (BUG-24).
    Widget slot(Widget child) => Expanded(child: child);
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
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 168),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < bars.length; index++) ...[
                  if (index > 0) const SizedBox(width: V2Space.xl),
                  slot(
                    _Bar(
                      display: bars[index].display,
                      height: maxValue == 0
                          ? 0
                          : bars[index].value / maxValue * _maxBarHeight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: V2Space.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < bars.length; index++) ...[
                if (index > 0) const SizedBox(width: V2Space.xl),
                slot(
                  // Nama bulan pendek (Sep/Okt/Nov) harus tetap satu baris dan
                  // sejajar dengan batangnya. Di skala teks 2.0 label membesar
                  // sampai membungkus dua baris ("Se"/"p") sehingga tidak lagi
                  // sebaris dengan batangnya (BUG-31). FittedBox menyusutkan
                  // sedikit agar tetap satu baris, bukan terpotong.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      bars[index].label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      style: V2Type.label.copyWith(color: V2Colors.muted),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: V2Space.sm),
          Text(caption, style: V2Type.label.copyWith(color: V2Colors.muted)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.display, required this.height});

  final String display;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: _chartValueStyle,
        ),
        const SizedBox(height: V2Space.xs),
        Center(
          child: Container(
            width: 64,
            height: height,
            decoration: const BoxDecoration(
              color: V2Colors.blue500,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }
}
