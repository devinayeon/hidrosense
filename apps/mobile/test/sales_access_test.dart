import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/nursery_repository.dart';
import 'package:hidrosense_mobile/viewmodels/connected_nursery_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/catat_penjualan_body.dart';
import 'package:hidrosense_mobile/views/components/penjualan_body.dart';
import 'package:hidrosense_mobile/views/pages/main_page.dart';
import 'package:hidrosense_mobile/views/pages/penjualan_page.dart';
import 'package:hidrosense_mobile/views/pages/catat_penjualan_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'support/damage_fixture.dart';

void main() {
  testWidgets(
    'employee cannot see sales tab, dashboard link, or direct sales routes',
    (tester) async {
      final api = apiFor((_) async => throw StateError('Unexpected API'));
      addTearDown(api.close);
      Future<void> pump(Widget home) => tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            sessionProvider.overrideWith(
              (_) => SessionViewModel(
                api,
                initialState: const SessionState(user: employee),
              ),
            ),
            connectedNurseryProvider.overrideWith(
              (_) => ConnectedNurseryViewModel(
                NurseryRepository(api),
                autoLoad: false,
              ),
            ),
          ],
          child: MaterialApp(theme: AppTheme.lightTheme, home: home),
        ),
      );
      await pump(const MainPage(initialIndex: 3));
      await tester.pumpAndSettle();
      expect(find.text('Penjualan'), findsNothing);
      expect(find.text('Penjualan & Kasir'), findsNothing);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0,
      );
      await pump(const PenjualanPage());
      await tester.pumpAndSettle();
      expect(find.byType(PenjualanBody), findsNothing);
      expect(find.text('Akses penjualan tidak diizinkan.'), findsOneWidget);
      await pump(const CatatPenjualanPage());
      await tester.pumpAndSettle();
      expect(find.byType(CatatPenjualanBody), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('farmer sales tab returns to home when permissions are removed', (
    tester,
  ) async {
    final api = apiFor((_) async => throw StateError('Unexpected API'));
    addTearDown(api.close);
    final activeUser = StateProvider<SessionUser?>((_) => farmer);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith(
            (ref) => SessionViewModel(
              api,
              initialState: SessionState(user: ref.watch(activeUser)),
            ),
          ),
          connectedNurseryProvider.overrideWith(
            (_) => ConnectedNurseryViewModel(
              NurseryRepository(api),
              autoLoad: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const MainPage(initialIndex: 3);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PenjualanBody), findsOneWidget);
    container.read(activeUser.notifier).state = employee;
    await tester.pumpAndSettle();
    expect(find.byType(PenjualanBody), findsNothing);
    expect(find.text('Penjualan'), findsNothing);
    expect(find.text('Penjualan & Kasir'), findsNothing);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('negative initial navigation index safely falls back to home', (
    tester,
  ) async {
    final api = apiFor((_) async => throw StateError('Unexpected API'));
    addTearDown(api.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith(
            (_) => SessionViewModel(
              api,
              initialState: const SessionState(user: farmer),
            ),
          ),
          connectedNurseryProvider.overrideWith(
            (_) => ConnectedNurseryViewModel(
              NurseryRepository(api),
              autoLoad: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainPage(initialIndex: -1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Penjualan & Kasir'), findsOneWidget);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      0,
    );
    expect(tester.takeException(), isNull);
  });
}
