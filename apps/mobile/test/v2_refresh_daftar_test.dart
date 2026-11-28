// Regresi fitur "Muat ulang daftar": setiap menu yang mengambil data dari
// backend harus bisa disegarkan lewat tarik-turun dan tombol di header/AppBar.
// Uji ini menjaga tiga hal: gestur memanggil sumber data tepat sekali, tombol
// memakai jalur yang sama dan tidak bisa ditekan ganda saat sibuk, dan galeri
// tanpa sumber data tidak berubah (tanpa indikator/tombol).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_akun_employee.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_akun_employee_store.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_store.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_cuaca_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_employee_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inventaris_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_notifications_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_sinkron_page.dart';
import 'package:hidrosense_mobile/views/v2/theme/v2_tokens.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_refresh_button.dart';

Future<void> _pumpTab(WidgetTester tester, Widget view) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: V2Theme.light,
      home: Scaffold(body: view),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: V2Theme.light, home: page));
  await tester.pumpAndSettle();
}

/// Tarik ke bawah dari atas daftar; indikator Material menahan gestur sampai
/// callback selesai, jadi `pumpAndSettle` sesudahnya menuntaskan animasinya.
Future<void> _pull(WidgetTester tester) async {
  expect(find.byType(RefreshIndicator), findsOneWidget);
  final scrollable = find
      .descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(SingleChildScrollView),
      )
      .first;
  await tester.drag(scrollable, const Offset(0, 320));
  await tester.pumpAndSettle();
}

class _CountingPenjualanStore implements V2PenjualanStore {
  int loads = 0;

  @override
  Future<V2PenjualanSnapshot> load() async {
    loads++;
    return const V2PenjualanSnapshot(items: [], panen: []);
  }

  @override
  Future<V2Penjualan> create(V2PenjualanDraft draft) =>
      throw UnimplementedError();

  @override
  Future<V2Penjualan> update(V2Penjualan existing, V2PenjualanDraft draft) =>
      throw UnimplementedError();

  @override
  Future<V2Penjualan> markPaid(V2Penjualan existing) =>
      throw UnimplementedError();

  @override
  Future<V2Penjualan> reload(V2Penjualan existing) =>
      throw UnimplementedError();
}

class _CountingEmployeeStore implements V2EmployeeStore {
  int loads = 0;

  @override
  Future<List<V2Employee>> list() async {
    loads++;
    return const <V2Employee>[];
  }

  @override
  Future<V2Employee> create(V2EmployeeDraft draft) =>
      throw UnimplementedError();

  @override
  Future<V2Employee> update(String id, V2EmployeeDraft draft) =>
      throw UnimplementedError();

  @override
  Future<V2Employee> deactivate(String id) => throw UnimplementedError();

  @override
  Future<V2Employee> activate(String id) => throw UnimplementedError();
}

void main() {
  testWidgets('tarik-turun memanggil onRefresh di tiap tab daftar', (
    tester,
  ) async {
    var stok = 0;
    await _pumpTab(
      tester,
      V2InventarisTabView(items: const [], onRefresh: () async => stok++),
    );
    await _pull(tester);
    expect(stok, 1);

    var semaian = 0;
    await _pumpTab(
      tester,
      V2SemaianTabView(items: const [], onRefresh: () async => semaian++),
    );
    await _pull(tester);
    expect(semaian, 1);

    var meja = 0;
    await _pumpTab(
      tester,
      V2MejaTabView(items: const [], onRefresh: () async => meja++),
    );
    await _pull(tester);
    expect(meja, 1);

    var panen = 0;
    await _pumpTab(
      tester,
      V2PanenTabView(
        estimasi: const [],
        riwayat: const [],
        onRefresh: () async => panen++,
      ),
    );
    await _pull(tester);
    expect(panen, 1);

    var rawat = 0;
    await _pumpTab(
      tester,
      V2RawatTabView(riwayat: const [], onRefresh: () async => rawat++),
    );
    await _pull(tester);
    expect(rawat, 1);
  });

  testWidgets('tanpa onRefresh galeri tetap tanpa indikator dan tombol', (
    tester,
  ) async {
    await _pumpTab(tester, V2InventarisTabView(items: const []));
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);

    await _pumpTab(tester, V2SemaianTabView(items: const []));
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);

    await _pumpTab(tester, V2MejaTabView(items: const []));
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);

    await _pumpTab(
      tester,
      V2PanenTabView(estimasi: const [], riwayat: const []),
    );
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);

    await _pumpTab(tester, V2RawatTabView(riwayat: const []));
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
  });

  testWidgets('tombol di header memakai jalur refresh yang sama', (
    tester,
  ) async {
    var calls = 0;
    await _pumpTab(
      tester,
      V2InventarisTabView(items: const [], onRefresh: () async => calls++),
    );
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('tombol sibuk menampilkan spinner dan menolak ketukan ganda', (
    tester,
  ) async {
    var calls = 0;
    final selesai = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light,
        home: Scaffold(
          body: Center(
            child: V2RefreshButton(
              onRefresh: () {
                calls++;
                return selesai.future;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(V2RefreshButton));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);

    // Ketukan kedua saat sibuk tidak memicu permintaan baru.
    await tester.tap(find.byType(V2RefreshButton));
    await tester.pump();
    expect(calls, 1);

    selesai.complete();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tombol refresh Penjualan memuat ulang store', (tester) async {
    final store = _CountingPenjualanStore();
    await _pumpPage(
      tester,
      V2PenjualanListPage(
        initialPenjualan: const [],
        store: store,
        onRefresh: store.load,
      ),
    );
    expect(store.loads, 1, reason: 'muat pertama saat halaman dibuka');

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(store.loads, 2);
  });

  testWidgets('tombol refresh Akun pegawai memuat ulang store', (tester) async {
    final store = _CountingEmployeeStore();
    await _pumpPage(tester, V2EmployeeListPage(store: store));
    expect(store.loads, 1, reason: 'muat pertama saat halaman dibuka');

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(store.loads, 2);
  });

  testWidgets('tarik-turun Notifikasi memakai grup terbaru', (tester) async {
    var calls = 0;
    await _pumpPage(
      tester,
      V2NotificationsPage(
        groups: const [
          V2NotificationGroup(
            label: 'Baru',
            items: [
              V2Notification(id: 'a', title: 'Notif lama', subtitle: '-'),
            ],
          ),
        ],
        onRefresh: () async {
          calls++;
          return const [
            V2NotificationGroup(
              label: 'Baru',
              items: [
                V2Notification(id: 'b', title: 'Notif baru', subtitle: '-'),
              ],
            ),
          ];
        },
      ),
    );
    expect(find.text('Notif lama'), findsOneWidget);

    await _pull(tester);
    expect(calls, 1);
    expect(find.text('Notif baru'), findsOneWidget);
    expect(find.text('Notif lama'), findsNothing);
  });

  testWidgets('tarik-turun Cuaca memanggil muat ulang BMKG', (tester) async {
    var calls = 0;
    await _pumpPage(tester, V2CuacaPage(onRefresh: () async => calls++));
    await _pull(tester);
    expect(calls, 1);
  });

  testWidgets('tarik-turun Sinkron memanggil sumber muat ulang', (
    tester,
  ) async {
    var calls = 0;
    await _pumpPage(tester, V2SinkronPage(onRefresh: () async => calls++));
    await _pull(tester);
    expect(calls, 1);
  });
}
