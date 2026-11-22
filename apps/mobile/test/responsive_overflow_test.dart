import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/components/custom_bottom_navigation_bar.dart';
import 'package:hidrosense_mobile/views/components/header.dart';
import 'package:hidrosense_mobile/views/pages/login_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_akun_employee.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_inventaris_catat_sheet.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_inventaris_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_panen_chart_card.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_panen_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_info_card.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_rawat_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_data.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_date_sheet.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_dialog.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_pick_sheet.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_akun_tab_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_cuaca_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_cycle_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_detail_tanaman_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_employee_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_employee_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_employee_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_home_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inactive_account_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inventaris_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inventaris_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inventaris_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_login_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_notification_permission_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_notifications_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_offline_login_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_onboarding_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_edit_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_summary_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pilih_semaian_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindah_meja_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_foto_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_hasil_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_konfirmasi_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_obat_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_edit_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_sinkron_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_tanaman_rusak_page.dart';

class _DeviceProfile {
  const _DeviceProfile(
    this.name,
    this.size, {
    this.textScale = 1.0,
    this.padding = EdgeInsets.zero,
    this.viewInsets = EdgeInsets.zero,
  });

  final String name;
  final Size size;
  final double textScale;
  final EdgeInsets padding;
  final EdgeInsets viewInsets;
}

const _profiles = <_DeviceProfile>[
  _DeviceProfile(
    'compact_320x568',
    Size(320, 568),
    padding: EdgeInsets.only(top: 20),
  ),
  _DeviceProfile(
    'android_360x640',
    Size(360, 640),
    padding: EdgeInsets.only(top: 24),
  ),
  _DeviceProfile(
    'android_360x640_scale13',
    Size(360, 640),
    textScale: 1.3,
    padding: EdgeInsets.only(top: 24),
  ),
  _DeviceProfile(
    'phone_390x844_safeArea',
    Size(390, 844),
    padding: EdgeInsets.only(top: 47, bottom: 34),
  ),
  _DeviceProfile(
    'phone_414x896_scale15',
    Size(414, 896),
    textScale: 1.5,
    padding: EdgeInsets.only(top: 47, bottom: 34),
  ),
  _DeviceProfile(
    'landscape_640x360',
    Size(640, 360),
  ),
  _DeviceProfile(
    'android_360x640_keyboard',
    Size(360, 640),
    padding: EdgeInsets.only(top: 24),
    viewInsets: EdgeInsets.only(bottom: 280),
  ),
  _DeviceProfile(
    'tablet_768x1024',
    Size(768, 1024),
    padding: EdgeInsets.only(top: 24, bottom: 20),
  ),
];

void main() {
  final screens = <String, Widget Function()>{
    // V2 Auth & Onboarding
    'V2OnboardingPage': () => const V2OnboardingPage(),
    'V2LoginPage': () => const V2LoginPage(),
    'V2InactiveAccountPage': () => const V2InactiveAccountPage(),
    'V2OfflineLoginPage': () => const V2OfflineLoginPage(),
    'V2NotificationPermissionPage': () => const V2NotificationPermissionPage(),
    // V2 Beranda & Siklus
    'V2BerandaPage_ready': () => const V2BerandaPage(),
    'V2BerandaPage_offline': () => const V2BerandaPage.offline(),
    'V2BerandaPage_weatherUnavailable': () =>
        const V2BerandaPage.weatherUnavailable(),
    'V2BerandaPage_loading': () => const V2BerandaPage.loading(),
    'V2HomePage': () => const V2HomePage(),
    'V2NotificationsPage': () => const V2NotificationsPage(),
    'V2CycleDetailPage': () => const V2CycleDetailPage(),
    // V2 Akun & Pegawai
    'V2AkunTabView_petani': () => const Scaffold(
      body: V2AkunTabView(role: V2BerandaRole.petani),
    ),
    'V2AkunTabView_pegawai': () => const Scaffold(
      body: V2AkunTabView(role: V2BerandaRole.pegawai),
    ),
    'V2EmployeeListPage': () => const V2EmployeeListPage(),
    'V2EmployeeDetailPage': () =>
        V2EmployeeDetailPage(employee: designEmployees.first),
    'V2EmployeeFormPage': () => const V2EmployeeFormPage.create(),
    // V2 Inventaris
    'V2InventarisListPage': () => const V2InventarisListPage(),
    'V2InventarisDetailPage': () =>
        V2InventarisDetailPage(item: designInventaris.first),
    'V2InventarisFormPage': () => const V2InventarisFormPage.create(),
    // V2 Semaian
    'V2SemaianListPage': () => const V2SemaianListPage(),
    'V2SemaianDetailPage': () =>
        V2SemaianDetailPage(item: designSemaian.first),
    'V2SemaianFormPage': () => const V2SemaianFormPage.create(),
    'V2SemaianEditPage': () => V2SemaianEditPage(item: designSemaian.first),
    'V2PindahMejaFormPage': () =>
        V2PindahMejaFormPage(item: designSemaian.first),
    'V2PindahMejaResultPage': () => const V2PindahMejaResultPage(
      title: 'Berhasil dipindah',
      body: '100 bibit dipindah ke Meja A2.',
      primaryLabel: 'Selesai',
    ),
    // V2 Meja & Tanaman
    'V2MejaListPage': () => const V2MejaListPage(),
    'V2MejaDetailPage': () => V2MejaDetailPage.biasa(),
    'V2MejaFormPage': () => const V2MejaFormPage.create(),
    'V2PilihSemaianPage': () => const V2PilihSemaianPage(),
    'V2DetailTanamanPage': () => V2DetailTanamanPage.biasa(),
    'V2UbahCatatanTanamanPage': () => const V2UbahCatatanTanamanPage.biasa(),
    'V2TanamanRusakPage': () => V2TanamanRusakPage(item: designMejaA2),
    'V2CatatRusakPage': () => const V2CatatRusakPage(),
    // V2 Panen
    'V2PanenListPage': () => const V2PanenListPage(),
    'V2PanenDetailPage': () => V2PanenDetailPage.biasa(),
    'V2PanenFormPage': () => const V2PanenFormPage(),
    'V2PanenEditPage': () => V2PanenEditPage.biasa(),
    // V2 Penjualan
    'V2PenjualanListPage': () => const V2PenjualanListPage(),
    'V2PenjualanSummaryPage': () => const V2PenjualanSummaryPage(),
    'V2PenjualanDetailPage': () =>
        V2PenjualanDetailPage(penjualan: designPenjualan.first),
    'V2PenjualanFormPage': () => const V2PenjualanFormPage(),
    // V2 Rawat
    'V2RawatListPage': () => const V2RawatListPage(),
    'V2RawatFotoPage': () => const V2RawatFotoPage(),
    'V2RawatHasilPage': () => const V2RawatHasilPage(),
    'V2RawatObatPage': () => const V2RawatObatPage.thrips(),
    'V2RawatKonfirmasiPage': () => const V2RawatKonfirmasiPage(),
    'V2RawatDetailPage': () =>
        V2RawatDetailPage(item: designRawatRiwayat.first),
    'V2RawatSavedPage': () => const V2RawatSavedPage(),
    // V2 Cuaca & Sinkron
    'V2CuacaPage_kondisi': () => const V2CuacaPage.kondisi(),
    'V2CuacaPage_prakiraan': () => const V2CuacaPage.prakiraan(),
    'V2CuacaPage_saran': () => const V2CuacaPage.saran(),
    'V2SinkronPage': () => const V2SinkronPage(),
    // V1 Key Screens
    'V1_LoginPage': () => const LoginPage(),
  };

  testWidgets('Audit overflow across all screens and device profiles', (
    tester,
  ) async {
    final failures = <String>[];
    final previousOnError = FlutterError.onError;

    for (final entry in screens.entries) {
      for (final profile in _profiles) {
        final errors = <String>[];
        FlutterError.onError = (details) {
          final msg = details.exceptionAsString();
          if (msg.contains('overflowed') || msg.contains('RenderFlex')) {
            final full = details.toString();
            final locMatch = RegExp(
              r'file:///[^)\n]+:\d+:\d+',
            ).firstMatch(full);
            final loc = locMatch == null
                ? ''
                : ' [${locMatch.group(0)!.split('/lib/').last}]';
            errors.add('${msg.split('\n').first}$loc');
          } else {
            previousOnError?.call(details);
          }
        };

        tester.view.physicalSize = profile.size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(
                    textScaler: TextScaler.linear(profile.textScale),
                    padding: profile.padding,
                    viewPadding: profile.padding,
                    viewInsets: profile.viewInsets,
                  ),
                  child: child!,
                );
              },
              home: entry.value(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        if (errors.isNotEmpty) {
          failures.add(
            '${entry.key} @ ${profile.name}: ${errors.toSet().join(" | ")}',
          );
        }
      }
    }

    FlutterError.onError = previousOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    if (failures.isNotEmpty) {
      fail('Found ${failures.length} overflow case(s):\n${failures.join('\n')}');
    }
  });

  testWidgets('Round 2: sheets, dialogs, special states, long data, v1 bars', (
    tester,
  ) async {
    final extraScreens = <String, Widget Function()>{
      // Sheets & Dialogs
      'V2PickSheet': () => const Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: V2PickSheet(
            title: 'Pilih jenis barang inventaris',
            options: [
              'Semua jenis',
              'Benih sayuran hidroponik',
              'Nutrisi AB Mix',
              'Media tanam rockwool',
              'Obat & pestisida nabati',
              'Peralatan greenhouse',
            ],
            selectedIndex: 1,
          ),
        ),
      ),
      'V2StockSheet': () => const Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: V2StockSheet(
            modeIndex: 1,
            value: 1250,
            unit: 'kilogram',
            error: 'Stok hanya 50 kilogram di gudang utama.',
          ),
        ),
      ),
      'V2DateSheet': () => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: V2DateSheet(
            monthLabel: 'November 2026',
            days: <int?>[
              null,
              null,
              null,
              null,
              null,
              null,
              for (var d = 1; d <= 30; d++) d,
            ],
            selectedDay: 15,
          ),
        ),
      ),
      'V2CatatStokSheet': () => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: V2CatatStokSheet(
            item: designInventaris.first,
            initialJumlah: 99,
          ),
        ),
      ),
      'V2Dialog': () => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: V2Dialog(
              title: 'Nonaktifkan akun pegawai?',
              body:
                  'Pegawai tidak bisa lagi masuk ke aplikasi sampai akun diaktifkan kembali oleh pemilik kebun.',
              type: V2DialogType.destructive,
              primaryLabel: 'Nonaktifkan akun',
              secondaryLabel: 'Batal',
            ),
          ),
        ),
      ),
      // Special states & skeletons
      'V2InventarisListPage_loading': () =>
          const V2InventarisListPage.loading(),
      'V2InventarisListPage_empty': () => const V2InventarisListPage.empty(),
      'V2InventarisListPage_error': () => const V2InventarisListPage.error(),
      'V2InventarisListPage_noResults': () =>
          const V2InventarisListPage.noResults(),
      'V2RawatListPage_memuat': () => const V2RawatListPage.memuat(),
      'V2CuacaPage_memuat': () => const V2CuacaPage.memuat(),
      'V2CuacaPage_bmkgGagal': () => const V2CuacaPage.bmkgGagal(),
      'V2CuacaPage_tanpaInternet': () => const V2CuacaPage.tanpaInternet(),
      'V2CuacaPage_saranKosong': () => const V2CuacaPage.saranKosong(),
      // Long dynamic data stress test
      'V2BerandaPage_longData': () => const V2BerandaPage(
        userName: 'Muhammad Abdurrahman Al-Farizi',
        siapPindahSubtitle: '15 semaian, HSS 17 siap pindah meja',
        lowStock: '1.250',
        filledHoles: '12.400',
        weatherTitle: 'Hujan Petir Lebat, 27°C',
        weatherSubtitle: 'Prakiraan hujan pukul 14.00–17.00',
      ),
      'V2CycleDetailPage_longName': () => const V2CycleDetailPage(
        tableName: 'Meja Hidroponik NFT Greenhouse Utara 01',
        weatherTitle: 'Hujan Petir Lebat, 27°C',
        weatherSubtitle: 'Prakiraan hujan pukul 14.00–17.00',
      ),
      'V2PenjualanInfoCard_longCurrency': () => const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: V2PenjualanInfoCard(
            rows: [
              V2PenjualanInfoRow(
                label: 'Total omzet bulan ini',
                value: 'Rp 1.250.500.000',
              ),
              V2PenjualanInfoRow(
                label: 'Rata-rata per transaksi',
                value: 'Rp 12.505.000',
              ),
            ],
          ),
        ),
      ),
      'V2PanenChartCard_stress': () => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: V2PanenChartCard(
            bars: designGrafikPanen,
            caption: 'Total berat layak tiga panen terakhir.',
          ),
        ),
      ),
      // V1 Navigation & Header
      'V1_Header_and_BottomNav': () => Scaffold(
        appBar: const Header(
          titleText: 'Daftar Inventaris Greenhouse',
          largeTitle: false,
          isScrolled: true,
          capsuleOnScroll: true,
          showBackButton: true,
        ),
        body: const SizedBox.expand(),
        bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: 0,
          onTap: (_) {},
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Inventaris',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.eco_outlined),
              activeIcon: Icon(Icons.eco),
              label: 'Semaian',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined),
              activeIcon: Icon(Icons.point_of_sale),
              label: 'Penjualan',
            ),
          ],
        ),
      ),
    };

    final failures = <String>[];
    final previousOnError = FlutterError.onError;

    for (final entry in extraScreens.entries) {
      for (final profile in _profiles) {
        final errors = <String>[];
        FlutterError.onError = (details) {
          final msg = details.exceptionAsString();
          if (msg.contains('overflowed') || msg.contains('RenderFlex')) {
            final full = details.toString();
            final locMatch = RegExp(
              r'file:///[^)\n]+:\d+:\d+',
            ).firstMatch(full);
            final loc = locMatch == null
                ? ''
                : ' [${locMatch.group(0)!.split('/lib/').last}]';
            errors.add('${msg.split('\n').first}$loc');
          } else {
            previousOnError?.call(details);
          }
        };

        tester.view.physicalSize = profile.size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(
                    textScaler: TextScaler.linear(profile.textScale),
                    padding: profile.padding,
                    viewPadding: profile.padding,
                    viewInsets: profile.viewInsets,
                  ),
                  child: child!,
                );
              },
              home: entry.value(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        if (errors.isNotEmpty) {
          failures.add(
            '${entry.key} @ ${profile.name}: ${errors.toSet().join(" | ")}',
          );
        }
      }
    }

    FlutterError.onError = previousOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    if (failures.isNotEmpty) {
      fail('Round 2 found ${failures.length} overflow case(s):\n${failures.join('\n')}');
    }
  });
}
