// Regresi BUG-24: pada skala teks sistem 200% beberapa kartu masih memotong
// atau menimpa teks: linimasa siklus, kartu "Siap pindah", kapsul status di
// daftar Tanaman, kartu Profil pegawai, grafik ringkasan penjualan, dan grid
// lubang meja. Uji ini merender tiap layar pada textScaler 2.0 di lebar ponsel
// dan memastikan Flutter tidak melaporkan overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_akun_employee.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_cycle_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_detail_tanaman_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_employee_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_employee_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inventaris_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_onboarding_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_summary_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindah_meja_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_konfirmasi_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_list_page.dart';

Future<void> _pumpScaled(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, w) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(2)),
        child: w!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Detail siklus: empat tahap tidak saling menimpa di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, const V2CycleDetailPage());

    expect(find.text('Semai'), findsOneWidget);
    expect(find.text('Pindah ke meja'), findsOneWidget);
    expect(find.text('Tumbuh'), findsOneWidget);
    expect(find.text('Panen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Detail semaian "Siap pindah": lencana tidak terpotong di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, V2SemaianDetailPage.siapPindah());

    expect(find.text('Siap pindah'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daftar semaian: kapsul status tetap utuh di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, const V2SemaianListPage());

    expect(tester.takeException(), isNull);
  });

  testWidgets('Daftar stok: kapsul menipis/habis tidak meluber di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, const V2InventarisListPage());

    expect(tester.takeException(), isNull);
  });

  testWidgets('Daftar meja: kapsul penuh tidak meluber di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, const V2MejaListPage());

    expect(tester.takeException(), isNull);
  });

  testWidgets('Detail meja: grid lubang dan legenda tidak bertumpuk di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, V2MejaDetailPage.biasa());

    expect(find.textContaining('Terisi'), findsWidgets);
    expect(find.textContaining('Kosong'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Detail pegawai: kartu profil + lencana aman di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(
      tester,
      const V2EmployeeDetailPage(
        employee: V2Employee(
          id: '2',
          name: 'Sari Dewi',
          username: 'sari.dewi',
          phone: '08123456789',
          address: 'Jl. Melati 5, Jember',
        ),
      ),
    );

    expect(find.textContaining('Sari Dewi'), findsWidgets);
    expect(find.text('Aktif'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ringkasan penjualan: label bulan sejajar grafik di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, const V2PenjualanSummaryPage());

    expect(find.text('Sep'), findsOneWidget);
    expect(find.text('Okt'), findsOneWidget);
    expect(find.text('Nov'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding: judul dan badan tidak terpotong di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, const V2OnboardingPage());

    expect(find.text('HidroSense'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Form pegawai: tombol "Tampilkan" tidak meluber di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, const V2EmployeeFormPage.validation());

    expect(find.text('Tampilkan'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pindah meja: stepper jumlah tidak meluber di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, V2PindahMejaFormPage.form());

    expect(tester.takeException(), isNull);
  });

  testWidgets('Rawat: kartu "Cek hama" tidak memotong ajakan di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, const V2RawatListPage.petani());

    expect(find.textContaining('AI bantu'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Form panen: kartu "Berat layak" tidak terpotong di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, const V2PanenFormPage.catat());

    expect(find.text('Berat layak'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Konfirmasi rawat: kartu stok berkurang utuh di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, const V2RawatKonfirmasiPage.biasa());

    expect(find.text('Stok berkurang'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Detail tanaman: label panen HST tidak meluber di skala 2.0', (
    tester,
  ) async {
    await _pumpScaled(tester, V2DetailTanamanPage.biasa());

    expect(tester.takeException(), isNull);
  });
}