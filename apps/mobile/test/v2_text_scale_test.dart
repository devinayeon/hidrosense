// Regresi BUG-20: pada skala teks sistem 200% beberapa layar utama meluber.
// Uji ini merender layar pada textScaler 2.0 di lebar ponsel dan memastikan
// tidak ada overflow (RenderFlex/RenderBox) yang dilaporkan Flutter.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_cuaca_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_sinkron_page.dart';

Widget _scaled(Widget child) => MaterialApp(
  builder: (context, w) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
    child: w!,
  ),
  home: child,
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_scaled(child));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Beranda tidak overflow di skala teks 2.0', (tester) async {
    await _pump(tester, const V2BerandaPage());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cuaca tidak overflow di skala teks 2.0', (tester) async {
    await _pump(tester, const V2CuacaPage());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sinkron tidak overflow di skala teks 2.0', (tester) async {
    await _pump(tester, const V2SinkronPage(state: V2SinkronState.partial));
    expect(tester.takeException(), isNull);
  });
}
