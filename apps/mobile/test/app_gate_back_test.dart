import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/app_gate.dart';
import 'package:hidrosense_mobile/views/pages/login_page.dart';
import 'support/damage_fixture.dart';

void main() {
  testWidgets(
    'system Back reaches session navigator and honors busy PopScope',
    (tester) async {
      final api = apiFor((_) async => reply({'data': {}}));
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            sessionProvider.overrideWith((_) => SessionViewModel(api)),
          ],
          child: const MaterialApp(home: AppGate()),
        ),
      );
      await tester.pumpAndSettle();
      final navigator = Navigator.of(tester.element(find.byType(LoginPage)));
      final saving = ValueNotifier(true);
      addTearDown(saving.dispose);
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => ValueListenableBuilder<bool>(
            valueListenable: saving,
            builder: (_, busy, _) => PopScope(
              canPop: !busy,
              child: const Scaffold(body: Text('Form meja dalam sesi')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Form meja dalam sesi'), findsOneWidget);
      saving.value = false;
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Form meja dalam sesi'), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );
}
