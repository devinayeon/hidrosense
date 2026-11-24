// Regresi BUG-31 (putaran 2): rincian penjualan per bulan dipindah dari label
// di bawah batang menjadi daftar ke bawah — nama bulan di kiri, nilai rata
// kanan — supaya skala teks 2.0 tidak lagi merusak kesejajaran grafik.
//
// Bukti gagal di kode lama: kode lama hanya punya satu teks gabungan
// "Sep 5,2 juta, Okt 6,4 juta, Nov 7,5 juta." dan label bulan di bawah tiap
// batang; `find.text('5,2 juta')` dan baris label+nilai tidak ada.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_summary_page.dart';
import 'package:hidrosense_mobile/views/v2/theme/v2_tokens.dart';

const List<String> _bulan = <String>['Sep', 'Okt', 'Nov'];
const List<String> _nilai = <String>['5,2 juta', '6,4 juta', '7,5 juta'];

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
  final topLeft = box.localToGlobal(Offset.zero);
  final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
  return Rect.fromPoints(topLeft, bottomRight);
}

void main() {
  for (final width in <double>[320, 360, 411]) {
    testWidgets('rincian bulan jadi daftar kiri-kanan di skala 2.0 (w$width)', (
      tester,
    ) async {
      await _pump(tester, Size(width, 1600), 2);

      final bars = _bars();
      expect(bars, findsNWidgets(3));

      // Semua batang berbagi dasar yang sama dan tidak ada label bulan yang
      // terselip di bawahnya lagi: rincian ada di bawah grafik.
      final bottoms = <double>[
        for (var i = 0; i < 3; i++) _rect(tester, bars.at(i)).bottom,
      ];
      expect(bottoms[0], closeTo(bottoms[1], 0.1));
      expect(bottoms[1], closeTo(bottoms[2], 0.1));

      for (var i = 0; i < _bulan.length; i++) {
        final label = find.text(_bulan[i]);
        final nilai = find.text(_nilai[i]);
        expect(label, findsOneWidget, reason: _bulan[i]);
        expect(nilai, findsOneWidget, reason: _nilai[i]);

        final labelRect = _rect(tester, label);
        final nilaiRect = _rect(tester, nilai);

        // Nama bulan dan nilainya satu baris.
        expect(
          nilaiRect.center.dy,
          closeTo(labelRect.center.dy, 1),
          reason: '"${_bulan[i]}" dan "${_nilai[i]}" tidak sebaris',
        );
        // Nama bulan di kiri, nilai di kanan.
        expect(nilaiRect.left, greaterThan(labelRect.right), reason: _bulan[i]);
        // Rincian berada di bawah batang, bukan label sejajar batang.
        expect(
          labelRect.top,
          greaterThan(bottoms[i]),
          reason: '"${_bulan[i]}" masih menempel di bawah batang',
        );
      }

      // Tidak ada lagi satu kalimat gabungan seperti versi lama.
      expect(
        find.text('Sep 5,2 juta, Okt 6,4 juta, Nov 7,5 juta.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rincian bulan terbaca pada skala 1.0', (tester) async {
    await _pump(tester, const Size(360, 1600), 1);

    for (var i = 0; i < _bulan.length; i++) {
      expect(find.text(_bulan[i]), findsOneWidget);
      expect(find.text(_nilai[i]), findsOneWidget);
      final labelRect = _rect(tester, find.text(_bulan[i]));
      final nilaiRect = _rect(tester, find.text(_nilai[i]));
      expect(nilaiRect.center.dy, closeTo(labelRect.center.dy, 1));
      expect(nilaiRect.left, greaterThan(labelRect.right));
    }
    expect(tester.takeException(), isNull);
  });
}