// Regresi BUG-30: notifikasi di halaman "2.4 Notifikasi" tidak bisa ditekan,
// status belum/sudah dibaca tidak ada, dan "Tandai semua dibaca" selalu aktif
// walau tak ada yang belum dibaca (D-23).
//
// Uji ini memastikan:
// - baris notifikasi bisa ditekan: menandai dibaca lalu mengembalikan tujuan;
// - penanda "belum dibaca" hanya muncul pada baris yang belum dibaca;
// - "Tandai semua dibaca" nonaktif saat tak ada yang belum dibaca;
// - Beranda membuka tab relevan setelah notifikasi ditekan;
// - status baca disimpan per pengguna dengan id stabil.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/data/services/notification_read_store.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_beranda_notifikasi.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_notifications_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_button.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const V2Notification _unreadSemaian = V2Notification(
  id: 'semaian-12',
  title: 'Semaian HSS 15',
  subtitle: 'Batch #12 siap pindah ke meja',
  target: V2NotificationTarget.semaian,
);

const V2Notification _unreadStok = V2Notification(
  id: 'stok-menipis',
  title: 'Stok menipis',
  subtitle: '2 barang di bawah minimum stok',
  target: V2NotificationTarget.stok,
);

const V2Notification _sudahDibaca = V2Notification(
  id: 'semaian-11',
  title: 'Semaian HSS 15',
  subtitle: '12 Nov, 08.00',
  read: true,
  target: V2NotificationTarget.semaian,
);

/// Menyimpan hasil ketukan dari halaman notifikasi.
class _Hasil {
  final List<String> ditandai = <String>[];
  List<String>? ditandaiSemua;
  V2NotificationTarget? tujuan;
}

Future<void> _pumpHalaman(
  WidgetTester tester,
  List<V2NotificationGroup> groups,
  _Hasil hasil,
) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              hasil.tujuan = await Navigator.of(context).push<V2NotificationTarget>(
                V2NotificationsPage.route(
                  groups: groups,
                  onMarkRead: hasil.ditandai.add,
                  onMarkAllRead: (ids) => hasil.ditandaiSemua = ids,
                ),
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

V2Button _tombolTandai(WidgetTester tester) => tester.widget<V2Button>(
  find.ancestor(
    of: find.text('Tandai semua dibaca'),
    matching: find.byType(V2Button),
  ),
);

void main() {
  sqfliteFfiInit();

  testWidgets('baris notifikasi bisa ditekan, menandai dibaca lalu membuka tujuan', (
    tester,
  ) async {
    final hasil = _Hasil();
    await _pumpHalaman(tester, const [
      V2NotificationGroup(label: 'Baru', items: [_unreadSemaian, _unreadStok]),
    ], hasil);

    await tester.tap(find.text('Semaian HSS 15'));
    await tester.pumpAndSettle();

    expect(hasil.ditandai, contains('semaian-12'));
    expect(hasil.tujuan, V2NotificationTarget.semaian);
    // Halaman ikut tertutup setelah memilih tujuan.
    expect(find.text('Notifikasi'), findsNothing);
  });

  testWidgets('penanda belum dibaca hanya pada baris yang belum dibaca', (
    tester,
  ) async {
    await _pumpHalaman(tester, const [
      V2NotificationGroup(
        label: 'Baru',
        items: [_unreadSemaian, _unreadStok],
      ),
      V2NotificationGroup(label: 'Sebelumnya', items: [_sudahDibaca]),
    ], _Hasil());

    expect(find.byKey(v2NotifUnreadDotKey), findsNWidgets(2));
  });

  testWidgets('tandai semua dibaca nonaktif bila tak ada yang belum dibaca', (
    tester,
  ) async {
    await _pumpHalaman(tester, const [
      V2NotificationGroup(label: 'Sebelumnya', items: [_sudahDibaca]),
    ], _Hasil());

    expect(_tombolTandai(tester).onPressed, isNull);
  });

  testWidgets('tandai semua dibaca menandai yang belum lalu menjadi nonaktif', (
    tester,
  ) async {
    final hasil = _Hasil();
    await _pumpHalaman(tester, const [
      V2NotificationGroup(
        label: 'Baru',
        items: [_unreadSemaian, _unreadStok],
      ),
      V2NotificationGroup(label: 'Sebelumnya', items: [_sudahDibaca]),
    ], hasil);

    expect(_tombolTandai(tester).onPressed, isNotNull);
    await tester.tap(find.text('Tandai semua dibaca'));
    await tester.pumpAndSettle();

    expect(hasil.ditandaiSemua, containsAll(<String>['semaian-12', 'stok-menipis']));
    expect(find.byKey(v2NotifUnreadDotKey), findsNothing);
    expect(_tombolTandai(tester).onPressed, isNull);
  });

  testWidgets('Beranda membuka tab Tanam setelah notifikasi semaian ditekan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: V2BerandaPage(
          notificationGroups: [
            V2NotificationGroup(label: 'Baru', items: [_unreadSemaian]),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    expect(find.text('Notifikasi'), findsOneWidget);

    await tester.tap(find.text('Semaian HSS 15'));
    await tester.pumpAndSettle();

    // Tab Tanam aktif: segmen Semaian/Meja/Panen muncul.
    expect(find.text('Meja'), findsOneWidget);
    expect(find.text('Panen'), findsOneWidget);
  });

  test('id notifikasi stabil dan status baca dihormati', () {
    final siap = SowingRecord(
      id: '12',
      userId: 'u1',
      sowingDate: '2026-01-01',
      seedCount: 100,
      status: 'aktif',
      ageDays: 15,
      isReadyToMove: true,
    );
    final menipis = InventoryRecord.fromJson({
      'id_inventaris': '7',
      'public_id': null,
      'version': null,
      'id_jenis_inventaris': '3',
      'id_obat': null,
      'nama_barang': 'Barang',
      'satuan': 'pak',
      'stok_minimum': '3',
      'status_aktif': 1,
      'nama_jenis': 'Benih',
      'nama_obat': null,
      'saldo': '2',
    });

    final groups = v2BerandaNotifikasi(
      nursery: [siap],
      inventaris: [menipis],
      sudahDibaca: {'semaian-12'},
    );

    final items = groups.single.items;
    final semaian = items.firstWhere((item) => item.id == 'semaian-12');
    final stok = items.firstWhere((item) => item.id == 'stok-menipis');
    expect(semaian.read, isTrue);
    expect(stok.read, isFalse);
    expect(semaian.target, V2NotificationTarget.semaian);
    expect(stok.target, V2NotificationTarget.stok);
  });

  test('status baca tersimpan per pengguna dan terpisah antar layanan', () async {
    final directory = await Directory.systemTemp.createTemp('notif_read_test_');
    final filename = path.join(directory.path, 'notif.db');
    final store = NotificationReadStore(
      await databaseFactoryFfi.openDatabase(
        filename,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: NotificationReadStore.createSchema,
        ),
      ),
    );

    await store.markRead(
      serverOrigin: 'http://a',
      userId: 'u1',
      notifId: 'semaian-12',
      readAt: DateTime(2026, 11, 24),
    );

    expect(
      await store.readIds(serverOrigin: 'http://a', userId: 'u1'),
      {'semaian-12'},
    );
    // Pengguna lain dan layanan lain tidak ikut terbaca.
    expect(await store.readIds(serverOrigin: 'http://a', userId: 'u2'), isEmpty);
    expect(
      await store.readIds(serverOrigin: 'http://b', userId: 'u1'),
      isEmpty,
    );

    await store.close();
    await directory.delete(recursive: true);
  });
}
