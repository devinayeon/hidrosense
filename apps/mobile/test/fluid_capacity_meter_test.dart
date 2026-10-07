import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/widgets/fluid_capacity_meter.dart';

void main() {
  group('FluidCapacityMeter HIG Animation & Rendering Tests', () {
    testWidgets('Merender okupansi dan animasi pengisian fluida dengan benar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidCapacityMeter(
              activePlants: 180,
              totalCapacity: 200,
              showLabel: true,
            ),
          ),
        ),
      );

      // Verifikasi teks rasio terpasang (180/200 = 90%)
      expect(find.text('Okupansi Meja NFT'), findsOneWidget);
      expect(find.text('180 / 200 Lubang (90%)'), findsOneWidget);

      // Pompa frame untuk memverifikasi animasi interpolasi cairan (450ms)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 225));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(FluidCapacityMeter), findsOneWidget);
    });

    testWidgets('Mode compact merender meter tanpa label teks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidCapacityMeter(
              activePlants: 50,
              totalCapacity: 100,
              showLabel: false,
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('Okupansi Meja NFT'), findsNothing);
      expect(find.byType(FluidCapacityMeter), findsOneWidget);
    });

    testWidgets('Menangani edge-case kapasitas 0 atau okupansi berlebih',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidCapacityMeter(
              activePlants: 10,
              totalCapacity: 0,
              showLabel: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(FluidCapacityMeter), findsOneWidget);
    });
  });
}
