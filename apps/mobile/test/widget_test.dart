import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/main.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_onboarding_page.dart';

void main() {
  testWidgets('Aplikasi membuka onboarding v2 tanpa data demo', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    expect(find.byType(V2OnboardingPage), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Benih Selada Grand Rapids'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  // Laporan pemilik (2026-11-23): layar meluap di HP dengan huruf sistem besar.
  testWidgets('skala huruf sistem dibatasi 1,5x di seluruh aplikasi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
        child: const ProviderScope(child: MyApp()),
      ),
    );
    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byType(V2OnboardingPage)),
    );
    expect(scaler.scale(10), 15);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
