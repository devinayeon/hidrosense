import 'package:flutter/material.dart';

import '../components/v2_penjualan_chart_card.dart';
import '../components/v2_penjualan_info_card.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';

/// Ringkasan penjualan (frame 8.5): grafik tiga bulan lalu kartu info.
///
/// Dibuka dari ikon grafik di AppBar daftar penjualan. Tanpa aksi di bawah.
class V2PenjualanSummaryPage extends StatelessWidget {
  const V2PenjualanSummaryPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const V2PenjualanSummaryPage(),
    );
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
                      const V2PenjualanChartCard(
                        title: 'Penjualan per bulan (juta Rp)',
                        caption: 'Sep 5,2 juta, Okt 6,4 juta, Nov 7,5 juta.',
                        bars: [
                          V2PenjualanChartBar(
                            label: 'Sep',
                            value: 5.2,
                            display: '5,2',
                          ),
                          V2PenjualanChartBar(
                            label: 'Okt',
                            value: 6.4,
                            display: '6,4',
                          ),
                          V2PenjualanChartBar(
                            label: 'Nov',
                            value: 7.5,
                            display: '7,5',
                          ),
                        ],
                      ),
                      const SizedBox(height: V2Space.lg),
                      const V2PenjualanInfoCard(
                        rows: [
                          V2PenjualanInfoRow(
                            label: 'Total 3 bulan',
                            value: 'Rp 19,1 jt',
                          ),
                          V2PenjualanInfoRow(
                            label: 'Rata-rata per kg',
                            value: 'Rp 39.000',
                          ),
                          V2PenjualanInfoRow(
                            label: 'Belum lunas',
                            value: 'Rp 2,4 jt',
                          ),
                        ],
                      ),
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
