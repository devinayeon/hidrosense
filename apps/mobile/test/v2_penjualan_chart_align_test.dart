// Regresi BUG-31: di skala teks 200% label bulan grafik "Ringkasan penjualan"
// membesar sampai membungkus dua baris ("Se"/"p") sehingga tidak lagi sebaris
// dengan batangnya. Uji ini memastikan tiap label bulan tetap satu baris dan
// titik pusatnya tepat di bawah titik pusat batangnya, pada skala 1.0 dan 2.0
// di beberapa lebar ponsel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_summary_page.dart';
import 'package:hidrosense_mobile/views/v2/theme/v2_tokens.dart';

const List<String> _bulan = <String>['Sep', 'Okt', 'Nov'];

Future<void> _pump(WidgetTester tester, Size size, double scale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, w) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: w!,
      ),
      home: const V2PenjualanSummaryPage(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Batang grafik dalam urutan tampil (Sep, Okt, Nov).
Finder _bars() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == V2Colors.blue500,
);

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  // localToGlobal atas size.center sudah menghitung transform FittedBox, jadi
  // ini pusat dan ukuran yang benar-benar terlihat di layar.
  final topLeft = box.localToGlobal(Offset.zero);
  final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
  return Rect.fromPoints(topLeft, bottomRight);
}

void main() {
  for (final width in <double>[320, 360, 411]) {
    testWidgets('label bulan sebaris dan sejajar batang di skala 2.0 (w$width)', (
      tester,
    ) async {
      await _pump(tester, Size(width, 1600), 2);

      final bars = _bars();
      expect(bars, findsNWidgets(3));

      // Semua batang berbagi dasar yang sama.
      final bottoms = <double>[
        for (var i = 0; i < 3; i++) _rect(tester, bars.at(i)).bottom,
      ];
      expect(bottoms[0], closeTo(bottoms[1], 0.1));
      expect(bottoms[1], closeTo(bottoms[2], 0.1));

      // Tiap label bulan tepat satu baris (tinggi satu baris ≈ 39 px di 2.0;
      // dua baris ≈ 78 px) dan titik pusatnya sejajar dengan batangnya.
      for (var i = 0; i < _bulan.length; i++) {
        final label = find.text(_bulan[i]);
        expect(label, findsOneWidget, reason: _bulan[i]);
        final labelRect = _rect(tester, label);
        final barRect = _rect(tester, bars.at(i));
        expect(
          labelRect.height,
          lessThan(50),
          reason: '"${_bulan[i]}" membungkus lebih dari satu baris',
        );
        expect(
          labelRect.center.dx,
          closeTo(barRect.center.dx, 0.5),
          reason: '"${_bulan[i]}" tidak sejajar dengan batangnya',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('label bulan tetap satu baris dan sejajar pada skala 1.0', (
    tester,
  ) async {
    await _pump(tester, const Size(360, 1600), 1);

    final bars = _bars();
    for (var i = 0; i < _bulan.length; i++) {
      final labelRect = _rect(tester, find.text(_bulan[i]));
      expect(labelRect.height, lessThan(30), reason: _bulan[i]);
      expect(
        labelRect.center.dx,
        closeTo(_rect(tester, bars.at(i)).center.dx, 0.5),
        reason: _bulan[i],
      );
    }
    expect(tester.takeException(), isNull);
  });
}
