// Fitur-1 (D-28): riwayat rotasi dikelompokkan per tanggal WIB dengan header
// tanggal; entri di bawah header tetap bisa dilipat dan aman di skala teks 2.0.
//
// Bukti gagal di kode lama: helper `kelompokkanRiwayatPerTanggal` dan
// `labelTanggalWib` belum ada, dan daftar lama hanya ListView.separated tanpa
// header tanggal, jadi `find.text('30 Sep 2026')` tidak menemukan apa pun.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_models.dart';
import 'package:hidrosense_mobile/features/pest/domain/pest_history_group.dart';
import 'package:hidrosense_mobile/features/pest/presentation/pages/rotation_history_page.dart';
import 'package:hidrosense_mobile/features/pest/presentation/viewmodels/pest_providers.dart';

import 'pest_viewmodels_test.dart' show FakeRepo;
import 'pest_widgets_test.dart' show rec;

PestRecommendation _pada(String id, String iso) =>
    rec(id: id, extra: {'tanggal_rekomendasi': iso});

void main() {
  test('kelompokkan per tanggal WIB, urut kemunculan (D-28)', () {
    final items = <PestRecommendation>[
      // 29 Sep 17:00Z = 30 Sep 00:00 WIB.
      _pada('a', '2026-09-29T17:00:00.000Z'),
      // 30 Sep 00:00Z = 30 Sep 07:00 WIB (satu kelompok dengan 'a').
      _pada('b', '2026-09-30T00:00:00.000Z'),
      _pada('c', '2026-09-28T00:00:00.000Z'),
      // Sudah dipakai: tanggal aplikasi menang.
      rec(id: 'd', status: 'diterima', extra: {'tanggal_aplikasi': '2026-10-01'}),
    ];

    final grup = kelompokkanRiwayatPerTanggal(items);
    expect(grup.length, 3);
    expect(grup[0].label, '30 Sep 2026');
    expect(grup[0].items.map((e) => e.id).toList(), ['a', 'b']);
    expect(grup[1].label, '28 Sep 2026');
    expect(grup[2].label, '1 Okt 2026');
  });

  testWidgets('daftar menampilkan header tanggal dan entri tetap bisa dilipat', (
    tester,
  ) async {
    final repo = FakeRepo()
      ..listFn = (s, k, p) => RecommendationPage(
        items: [
          _pada('1', '2026-09-30T00:00:00.000Z'),
          _pada('2', '2026-09-30T05:00:00.000Z'),
          _pada('3', '2026-09-28T00:00:00.000Z'),
        ],
        page: 1,
        totalPages: 1,
      );

    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pestRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: RotationHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Dua tanggal: 30 Sep (dua entri) dan 28 Sep (satu entri).
    expect(find.text('30 Sep 2026'), findsOneWidget);
    expect(find.text('28 Sep 2026'), findsOneWidget);
    expect(find.text('Lihat detail'), findsNWidgets(3));

    // Entri di bawah header tetap bisa dibuka.
    await tester.tap(find.text('Lihat detail').first);
    await tester.pumpAndSettle();
    expect(find.text('Spinosad'), findsOneWidget);
  });

  testWidgets('header tanggal aman di skala teks 2.0', (tester) async {
    final repo = FakeRepo()
      ..listFn = (s, k, p) => RecommendationPage(
        items: [_pada('1', '2026-09-30T00:00:00.000Z')],
        page: 1,
        totalPages: 1,
      );

    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pestRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          builder: (context, w) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: w!,
          ),
          home: const RotationHistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('30 Sep 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}