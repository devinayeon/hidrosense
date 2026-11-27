// Regresi batch perbaikan Penjualan (sesi ini): setiap penjualan dianggap
// lunas, jadi tidak ada lagi isian "Pembayaran", saringan "Lunas / Belum
// lunas", lencana status bayar, baris "Belum lunas" di ringkasan, maupun
// tombol "Tandai lunas" di Detail. Data lama tanpa penanda bayar tetap tampil.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_row.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_summary_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_chip.dart';

void main() {
  testWidgets('form catat penjualan tanpa isian status pembayaran', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2PenjualanFormPage.create()),
    );

    expect(find.text('Pembayaran'), findsNothing);
    expect(find.text('Lunas'), findsNothing);
    expect(find.text('Belum lunas'), findsNothing);
  });

  testWidgets('daftar penjualan tanpa saringan dan tanpa baris belum lunas', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: V2PenjualanListPage()));

    expect(find.byType(V2Chip), findsNothing);
    expect(find.text('Belum lunas'), findsNothing);
    expect(find.text('Lunas'), findsNothing);
  });

  testWidgets('baris penjualan hanya berlencana Antrean', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              V2PenjualanRow(penjualan: penjualanTokoSegar),
              V2PenjualanRow(penjualan: penjualanWarungSariAntrean),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Belum lunas'), findsNothing);
    expect(find.text('Lunas'), findsNothing);
    expect(find.text('Antrean'), findsOneWidget);
  });

  testWidgets('detail penjualan tanpa tombol Tandai lunas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: V2PenjualanDetailPage.tokoSegar()),
    );

    expect(find.text('Tandai lunas'), findsNothing);
    expect(find.text('Belum lunas'), findsNothing);
    expect(find.text('Ubah'), findsOneWidget);
  });

  testWidgets('ringkasan penjualan tanpa baris Belum lunas', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: V2PenjualanSummaryPage()));

    expect(find.text('Belum lunas'), findsNothing);
    expect(find.text('Total 3 bulan'), findsOneWidget);
    expect(find.text('Rata-rata per kg'), findsOneWidget);
  });

  test('ringkasan penjualan tidak punya hitungan belum lunas', () {
    final ringkasan = ringkasanPenjualan([
      penjualanTokoSegar,
      penjualanPasarInduk,
    ], kicker: 'November 2026');
    expect(ringkasan.total, isNotEmpty);
    expect(ringkasan.kgTerjual, contains('terjual'));

    final bulanan = ringkasanBulananPenjualan([
      penjualanTokoSegar,
    ], sekarang: DateTime(2026, 11, 27));
    expect(bulanan.bulan, hasLength(3));
    expect(bulanan.totalTigaBulan, greaterThan(0));
  });
}
