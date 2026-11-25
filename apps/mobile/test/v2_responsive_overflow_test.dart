import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/models/weather_location.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_cuaca_lokasi_sheet.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_cuaca_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inventaris_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_login_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_onboarding_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_sinkron_page.dart';

// Laporan pemilik (2026-11-23): "BOTTOM OVERFLOWED BY n PIXELS" muncul di HP
// pemilik (font/tampilan sistem lebih besar) tetapi tidak di HP tim. Setiap
// layar utama harus muat di semua ukuran layar dan skala huruf berikut.
const _sizes = <Size>[
  Size(320, 568), // HP kecil lama
  Size(360, 640),
  Size(360, 800), // HP pemilik (720x1600 @2x)
  Size(412, 915),
  Size(600, 960), // tablet kecil / lipat
];
// 1,5 adalah batas yang diizinkan `MyApp` (lihat main.dart); skala sistem di
// atasnya dibatasi ke 1,5 sebelum sampai ke layar mana pun.
const _scales = <double>[1.0, 1.15, 1.3, 1.5];

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required Size size,
  required double scale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(scale),
        padding: const EdgeInsets.only(top: 24, bottom: 16),
      ),
      child: MaterialApp(debugShowCheckedModeBanner: false, home: page),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  tearDown(() {});

  final screens = <String, Widget Function()>{
    'onboarding': () => const V2OnboardingPage(initialSlide: 2),
    'onboarding slide 3': () => const V2OnboardingPage(initialSlide: 3),
    'login': () => const V2LoginPage(),
    'beranda': () => const V2BerandaPage(),
    'semaian': () => const V2SemaianListPage.ready(),
    'meja': () => const V2MejaListPage.petani(),
    'panen': () => const V2PanenListPage.petani(),
    'stok': () => const V2InventarisListPage.ready(),
    'rawat': () => const V2RawatListPage.petani(),
    'cuaca': () => const V2CuacaPage(),
    'sinkron': () => const V2SinkronPage(),
    'penjualan': () => V2PenjualanListPage.empty(),
    'sheet lokasi cuaca': () => Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: V2CuacaLokasiSheet(
          current: WeatherLocation.partner,
          loadRegions: (level, parent) async => [
            for (var i = 0; i < 12; i++)
              WeatherRegion(
                id: '$i',
                name: 'Kabupaten Dengan Nama Wilayah Yang Sangat Panjang $i',
              ),
          ],
          locateDevice: () async => WeatherLocation.partner,
        ),
      ),
    ),
  };

  for (final entry in screens.entries) {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets(
          '${entry.key} muat di ${size.width.toInt()}x${size.height.toInt()} '
          'skala huruf $scale',
          (tester) async {
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await _pump(tester, entry.value(), size: size, scale: scale);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  // Bilah tab bawah ada di beranda; periksa tiap tab setelah dibuka.
  for (final size in _sizes) {
    for (final scale in _scales) {
      testWidgets(
        'tab beranda muat di ${size.width.toInt()}x${size.height.toInt()} '
        'skala huruf $scale',
        (tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await _pump(tester, const V2BerandaPage(), size: size, scale: scale);
          for (final label in ['Tanam', 'Stok', 'Rawat', 'Lainnya']) {
            await tester.tap(find.text(label).last);
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull, reason: 'tab $label meluap');
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
