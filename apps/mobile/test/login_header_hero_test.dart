import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/widgets/wavy_header_clipper.dart';
import 'package:hidrosense_mobile/features/auth/presentation/widgets/login_header_hero.dart';
import 'package:hidrosense_mobile/views/pages/login_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets('Brand entrance respects Reduce Motion: $reduceMotion', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
            home: const LoginPage(),
          ),
        ),
      );
      final portraitScale = find.ancestor(
        of: find.byType(ClipRSuperellipse),
        matching: find.byType(ScaleTransition),
      );
      final scale = tester.widget<ScaleTransition>(portraitScale).scale;
      if (reduceMotion) {
        expect(scale.value, 1);
      } else {
        expect(scale.value, lessThan(1));
        await tester.pump(const Duration(milliseconds: 140));
        expect(scale.value, greaterThan(0.96));
      }
      await tester.pumpAndSettle();
      expect(scale.value, 1);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.first.autofillHints, [AutofillHints.username]);
      expect(fields.last.autofillHints, [AutofillHints.password]);
      expect(fields.last.obscureText, isTrue);
      final toggle = find.byTooltip('Tampilkan kata sandi');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .obscureText,
        isFalse,
      );
      expect(scale.value, 1);
      expect(find.byTooltip('Sembunyikan kata sandi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Login stays scrollable with large text and the keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(LoginHeaderHero)), Offset.zero);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Masuk')).bottom, lessThan(568));

    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    final password = find.byType(TextFormField).last;
    await tester.ensureVisible(password);
    await tester.tap(password);
    await tester.pumpAndSettle();
    expect(tester.getRect(password).bottom, lessThanOrEqualTo(328));
    expect(tester.getSize(find.byType(LoginHeaderHero)).height, 240);
    expect(tester.takeException(), isNull);
  });

  group('TopHeroWaveClipper Geometry Tests', () {
    test('Calculates valid closed Bézier wave path within boundary size', () {
      const clipper = TopHeroWaveClipper();
      const testSize = Size(400, 300);
      final path = clipper.getClip(testSize);

      expect(path, isNotNull);
      final bounds = path.getBounds();

      // Bounding box must start at 0,0 and span full width
      expect(bounds.left, equals(0.0));
      expect(bounds.top, equals(0.0));
      expect(bounds.right, equals(testSize.width));
      expect(bounds.bottom, lessThanOrEqualTo(testSize.height));

      // Clipper should not unnecessarily reclip static curves
      expect(clipper.shouldReclip(const TopHeroWaveClipper()), isFalse);
    });
  });

  group('LoginHeaderHero Widget Tests', () {
    for (final viewport in [
      (size: const Size(320, 568), height: 240.0),
      (size: const Size(390, 844), height: 270.08),
      (size: const Size(1024, 1366), height: 300.0),
    ]) {
      testWidgets('Fits viewport ${viewport.size} without safe-area inset', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport.size;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: LoginHeaderHero())),
        );

        final hero = find.byType(LoginHeaderHero);
        expect(tester.getTopLeft(hero), Offset.zero);
        expect(tester.getSize(hero).width, viewport.size.width);
        expect(tester.getSize(hero).height, closeTo(viewport.height, 0.01));

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        expect(tester.getSize(hero).height, closeTo(viewport.height, 0.01));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Keeps the wave and placeholder when artwork is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginHeaderHero(imageAssetPath: 'assets/missing.png'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ClipPath), findsOneWidget);
      expect(find.byType(DecoratedBox), findsOneWidget);
      expect(tester.getSize(find.byType(LoginHeaderHero)).height, 240);
    });

    testWidgets(
      'Renders ClipPath with TopHeroWaveClipper and respects clamped bounds',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [LoginHeaderHero(), SizedBox(height: 50)],
                ),
              ),
            ),
          ),
        );

        // Verify widget presence
        expect(find.byType(LoginHeaderHero), findsOneWidget);
        expect(find.byType(ClipPath), findsOneWidget);

        final clipPathWidget = tester.widget<ClipPath>(find.byType(ClipPath));
        expect(clipPathWidget.clipper, isA<TopHeroWaveClipper>());

        // Verify custom height override
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: LoginHeaderHero(height: 280))),
        );

        final sizedBoxFinder = find.byType(SizedBox).first;
        final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
        expect(sizedBox.height, equals(280.0));
      },
    );
  });
}
