// Regresi BUG-32: filter riwayat rotasi terlalu rapat dan daftarnya terlalu
// panjang. Sekarang filter dibungkus (Wrap) dengan jarak token V2Space yang
// lebih lega, dan tiap entri bisa dilipat: tertutup = ringkasan 1–2 baris,
// terbuka = rincian lengkap. Diuji juga pada skala teks 2.0.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_models.dart';
import 'package:hidrosense_mobile/features/pest/presentation/pages/rotation_history_page.dart';
import 'package:hidrosense_mobile/features/pest/presentation/viewmodels/pest_providers.dart';

import 'pest_viewmodels_test.dart' show FakeRepo;
import 'pest_widgets_test.dart' show rec;

Future<void> _pump(
  WidgetTester tester,
  FakeRepo repo, {
  double scale = 1,
  Size size = const Size(360, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pestRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        builder: (context, w) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: w!,
        ),
        home: const RotationHistoryPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FakeRepo _repo(int count) => FakeRepo()
  ..listFn = (s, k, p) => RecommendationPage(
    items: [
      for (var i = 0; i < count; i++)
        rec(id: '$i', status: 'menunggu', extra: const {}),
    ],
    page: 1,
    totalPages: 1,
  );

void main() {
  testWidgets('entri tertutup ringkas, bisa dibuka lalu ditutup', (tester) async {
    await _pump(tester, _repo(2));

    // Tertutup: dua ringkasan, tanpa rincian.
    expect(find.text('Lihat detail'), findsNWidgets(2));
    expect(find.text('Masa tunggu panen: cek label produk.'), findsNothing);
    expect(tester.takeException(), isNull);

    // Buka entri pertama.
    await tester.tap(find.text('Lihat detail').first);
    await tester.pumpAndSettle();
    expect(find.text('Spinosad'), findsOneWidget);
    expect(find.text('Masa tunggu panen: cek label produk.'), findsOneWidget);
    expect(find.text('Sembunyikan detail'), findsOneWidget);

    // Tutup lagi (header tanggal menggeser kartu; pastikan terlihat dulu).
    await tester.ensureVisible(find.text('Sembunyikan detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sembunyikan detail'));
    await tester.pumpAndSettle();
    expect(find.text('Spinosad'), findsNothing);
    expect(find.text('Lihat detail'), findsNWidgets(2));
  });

  testWidgets('filter dan kartu ringkas tidak overflow di skala 2.0', (
    tester,
  ) async {
    await _pump(tester, _repo(3), scale: 2);

    // Filter tetap tampil dan boleh membungkus.
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Semua hama'), findsOneWidget);
    // Daftar malas membangun; cukup pastikan entri ringkas muncul.
    expect(find.text('Lihat detail'), findsWidgets);

    // Buka satu entri di skala 2.0: tetap tidak overflow.
    await tester.ensureVisible(find.text('Lihat detail').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat detail').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
