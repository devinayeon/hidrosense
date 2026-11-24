import 'package:flutter/material.dart';

import '../components/v2_penjualan_chart_card.dart';
import '../components/v2_penjualan_data.dart';
import '../components/v2_penjualan_info_card.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';

/// Ringkasan penjualan (frame 8.5): grafik tiga bulan lalu kartu info.
///
/// Dibuka dari ikon grafik di AppBar daftar penjualan. Tanpa aksi di bawah.
/// [bulanan] berisi agregat dari data nyata; null berarti galeri memakai
/// angka contoh yang persis frame 8.5.
class V2PenjualanSummaryPage extends StatelessWidget {
  const V2PenjualanSummaryPage({super.key, this.bulanan});

  final V2PenjualanRingkasanBulanan? bulanan;

  static Route<void> route({V2PenjualanRingkasanBulanan? bulanan}) {
    return MaterialPageRoute<void>(
      builder: (_) => V2PenjualanSummaryPage(bulanan: bulanan),
    );
  }

  /// Batang grafik: dari tiga bulan nyata, atau contoh galeri.
  List<V2PenjualanChartBar> get _bars {
    final bulanan = this.bulanan;
    if (bulanan == null) {
      return const [
        V2PenjualanChartBar(label: 'Sep', value: 5.2, display: '5,2'),
        V2PenjualanChartBar(label: 'Okt', value: 6.4, display: '6,4'),
        V2PenjualanChartBar(label: 'Nov', value: 7.5, display: '7,5'),
      ];
    }
    return [
      for (final item in bulanan.bulan)
        V2PenjualanChartBar(
          label: item.label,
          value: item.juta,
          display: item.display,
        ),
    ];
  }

  /// Kartu info: total tiga bulan, rata-rata per kg, dan sisa belum lunas.
  List<V2PenjualanInfoRow> get _rows {
    final bulanan = this.bulanan;
    if (bulanan == null) {
      return const [
        V2PenjualanInfoRow(label: 'Total 3 bulan', value: 'Rp 19,1 jt'),
        V2PenjualanInfoRow(label: 'Rata-rata per kg', value: 'Rp 39.000'),
        V2PenjualanInfoRow(label: 'Belum lunas', value: 'Rp 2,4 jt'),
      ];
    }
    return [
      V2PenjualanInfoRow(
        label: 'Total 3 bulan',
        value: formatRupiahJuta(bulanan.totalTigaBulan),
      ),
      V2PenjualanInfoRow(
        label: 'Rata-rata per kg',
        value: 'Rp ${formatAngkaRibu(bulanan.rataRataPerKg.round())}',
      ),
      V2PenjualanInfoRow(
        label: 'Belum lunas',
        value: formatRupiahJuta(bulanan.belumLunas),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Ringkasan penjualan',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      V2PenjualanChartCard(
                        title: 'Penjualan per bulan (juta Rp)',
                        bars: _bars,
                      ),
                      const SizedBox(height: V2Space.lg),
                      V2PenjualanInfoCard(rows: _rows),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
