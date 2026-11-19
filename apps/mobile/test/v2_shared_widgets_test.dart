import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hidrosense_mobile/views/v2/pages/v2_cycle_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/theme/v2_tokens.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_action_bar.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_banner.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_bottom_sheet.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_button.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_icon.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_status_bar.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_tab_bar.dart';

Future<void> _loadPoppins() async {
  final bytes = await File(
    'lib/views/v2/fonts/Poppins-Regular.ttf',
  ).readAsBytes();
  final loader = FontLoader('Poppins')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

void main() {
  setUpAll(_loadPoppins);

  group('V2TabBar', () {
    testWidgets('tinggi 106 seperti frame Foundations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 390,
                child: V2TabBar(
                  items: [
                    V2TabItem(label: 'Beranda', icon: V2IconName.home),
                    V2TabItem(label: 'Tanam', icon: V2IconName.sprout),
                  ],
                  activeIndex: 0,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(V2TabBar)).height, 106);
    });

    testWidgets('batang home indicator 8 di atas tepi bawah', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: V2HomeIndicator())),
      );

      final indicator = tester.getRect(find.byType(V2HomeIndicator));
      final bar = tester.getRect(
        find.descendant(
          of: find.byType(V2HomeIndicator),
          matching: find.byType(Container),
        ),
      );

      expect(indicator.height, 34);
      expect(bar.height, 5);
      expect(bar.width, 134);
      expect(indicator.bottom - bar.bottom, 8);
    });
  });

  group('V2ActionBar', () {
    testWidgets('dua tombol tetap menyisakan 8 di dalam SafeArea', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(child: SizedBox()),
                V2ActionBar(
                  actions: [
                    V2Button(label: 'Simpan'),
                    V2Button(label: 'Batal', type: V2ButtonType.tertiary),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      final screen = tester.getRect(find.byType(Scaffold));
      final last = tester.getRect(find.byType(V2Button).last);
      expect(screen.bottom - last.bottom, V2Space.sm);
    });
  });

  group('V2Banner', () {
    testWidgets('nada AI memakai teks charcoal', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: V2Banner(
              message: 'Saran AI membantu.',
              tone: V2BannerTone.ai,
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Saran AI membantu.'));
      expect(text.style?.color, V2Colors.ink);
    });
  });

  group('showV2BottomSheet', () {
    testWidgets('scrim memakai charcoal 60%', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (inner) {
              context = inner;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      showV2BottomSheet<void>(
        context,
        child: const V2BottomSheet(title: 'Pilih'),
      );
      await tester.pumpAndSettle();

      final barriers = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .toList();
      final barrier = barriers.lastWhere((item) => item.color != null);
      expect(barrier.color!.a, closeTo(0.6, 0.01));
    });
  });

  testWidgets('detail siklus menampilkan kartu cuaca dan membuka callback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: V2CycleDetailPage(
          tableName: 'Meja A2',
          weatherTitle: 'Berawan, 29°C',
          weatherSubtitle: 'Hujan 14.00',
          onOpenWeather: () => opened++,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Berawan, 29°C'), findsOneWidget);
    expect(find.text('Hujan 14.00'), findsOneWidget);

    await tester.tap(find.text('Berawan, 29°C'));
    expect(opened, 1);
  });
}
