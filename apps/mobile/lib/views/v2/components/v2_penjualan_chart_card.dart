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
/// Kartu putih bersudut 24 dengan judul dan tiga batang biru bertumpu pada
/// garis bawah. Rincian bulan tidak lagi ditulis di bawah batang: label bulan
/// membesar sampai membungkus dua baris pada skala teks 2.0 sehingga tidak
/// sejajar dengan batangnya (BUG-31). Rincian dipindah ke daftar ke bawah,
/// nama bulan di kiri dan nilai rata kanan, yang tetap terbaca di semua skala.
class V2PenjualanChartCard extends StatelessWidget {
  const V2PenjualanChartCard({
    super.key,
    required this.title,
    required this.bars,
  });

  final String title;
  final List<V2PenjualanChartBar> bars;

  static const double _maxBarHeight = 120;

  @override
  Widget build(BuildContext context) {
    final maxValue = bars.fold<double>(0, (a, b) => b.value > a ? b.value : a);
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
          const SizedBox(height: V2Space.lg),
          // Rincian per bulan sebagai daftar ke bawah: nama bulan di kiri,
          // nilai juta rata kanan. Tidak ada label di bawah batang lagi, jadi
          // skala teks besar tidak bisa merusak kesejajaran grafik (BUG-31).
          for (var index = 0; index < bars.length; index++) ...[
            if (index > 0) const SizedBox(height: V2Space.sm),
            _BarisRincian(
              label: bars[index].label,
              value: '${bars[index].display} juta',
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris rincian bulan: nama bulan di kiri, nilai rata kanan.
class _BarisRincian extends StatelessWidget {
  const _BarisRincian({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = V2Type.label.copyWith(color: V2Colors.muted);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: muted,
          ),
        ),
        const SizedBox(width: V2Space.md),
        // Nilai tidak boleh membungkus: di skala 2.0 teks "juta" bisa turun ke
        // baris kedua. FittedBox menyusutkan sedikit hanya bila ruang tidak
        // cukup, jadi tetap satu baris dan rata kanan.
        Expanded(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: _chartValueStyle,
            ),
          ),
        ),
      ],
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
