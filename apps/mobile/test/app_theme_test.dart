import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/components/custom_bottom_navigation_bar.dart';
import 'package:hidrosense_mobile/views/components/info_meja_body.dart';
import 'package:hidrosense_mobile/views/pages/info_seeding_page.dart';
import 'package:hidrosense_mobile/models/meja_nft_model.dart';
import 'package:hidrosense_mobile/models/seeding_batch_model.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';

void main() {
  group('AppColors HIG Palette Integrity', () {
    test('Warna brand dan aksen mempertahankan nilai hex eksisting', () {
      expect(AppColors.primaryMint, const Color(0xFF39C6C5));
      expect(AppColors.primaryDarkTeal, const Color(0xFF168681));
      expect(AppColors.accentLime, const Color(0xFFDDF45A));
      expect(AppColors.darkNavy, const Color(0xFF172231));
      expect(AppColors.canvasWarm, const Color(0xFFFAFAF7));
      expect(AppColors.warningOrange, const Color(0xFFFF9A55));
    });

    test('Warna semantik status terdefinisi dengan kontras yang tepat', () {
      expect(AppColors.successGreen, const Color(0xFF10B981));
      expect(AppColors.dangerRed, const Color(0xFFEF4444));
      expect(AppColors.infoBlue, const Color(0xFF3B82F6));
    });
  });

  group('AppSpacing & AppRadius Token Rhythm', () {
    test('Spasi mengikuti ritme kelipatan 4pt & 8pt HIG', () {
      expect(AppSpacing.xxs, 4.0);
      expect(AppSpacing.xs, 8.0);
      expect(AppSpacing.sm, 12.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 20.0);
      expect(AppSpacing.xl, 24.0);
      expect(AppSpacing.xxl, 32.0);
    });

    test('Radius sudut continuous squircle memenuhi standar HIG', () {
      expect(AppRadius.badge, 8.0);
      expect(AppRadius.input, 12.0);
      expect(AppRadius.card, 16.0);
      expect(AppRadius.modal, 24.0);
      expect(AppRadius.pill, 999.0);
    });
  });

  group('AppTypography & Tabular Numerics', () {
    test('Font family default menggunakan Inter', () {
      expect(AppTypography.fontFamily, 'Inter');
    });

    test('Tabular helper menambahkan font feature tabular figures', () {
      const base = AppTypography.headline;
      final tabularStyle = AppTypography.tabular(base);
      expect(tabularStyle.fontFeatures, isNotNull);
      expect(
        tabularStyle.fontFeatures!.any((f) => f.feature == 'tnum'),
        isTrue,
      );
    });
  });

  group('AppShadows Soft Diffusion', () {
    test('Elevation shadows terdefinisi dengan blur dan spread HIG', () {
      expect(AppShadows.subtle.length, 1);
      expect(AppShadows.subtle.first.blurRadius, 8.0);
      expect(AppShadows.floating.first.blurRadius, 16.0);
      expect(AppShadows.modal.first.blurRadius, 24.0);
    });
  });

  group('AppTheme.lightTheme Configuration', () {
    test(
      'ThemeData mengonfigurasi scaffold, card, input, dan buttons dengan benar',
      () {
        final theme = AppTheme.lightTheme;
        expect(theme.useMaterial3, isTrue);
        expect(theme.scaffoldBackgroundColor, AppColors.canvasWarm);
        expect(theme.colorScheme.primary, AppColors.primaryDarkTeal);
        expect(theme.colorScheme.secondary, AppColors.primaryMint);

        // Verifikasi CardTheme
        expect(theme.cardTheme.color, AppColors.cardSurface);
        expect(theme.cardTheme.elevation, 0);

        // Verifikasi ElevatedButtonTheme (Touch Target >= 44pt)
        final elevatedStyle = theme.elevatedButtonTheme.style;
        expect(elevatedStyle, isNotNull);

        // Verifikasi BottomSheetTheme
        expect(theme.bottomSheetTheme.backgroundColor, AppColors.cardSurface);
      },
    );
  });

  testWidgets('bottom navigation reports selected tab changes', (tester) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CustomBottomNavigationBar(
            currentIndex: 0,
            onTap: (index) => selectedIndex = index,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory),
                label: 'Inventaris',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Inventaris'));
    expect(selectedIndex, 1);
  });

  testWidgets('table occupancy progress animates over HIG duration', (
    tester,
  ) async {
    final table = MejaNft(
      id: '1',
      name: 'M-01',
      status: MejaStatus.aktif,
      capacityTotal: 100,
      capacityUsed: 50,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: InfoMejaBody(mejaItem: table)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 225));
    final fill = find.byKey(const ValueKey('fluid-capacity-fill'));
    final track = find.ancestor(of: fill, matching: find.byType(LayoutBuilder));
    final halfwayWidth = tester.getSize(fill).width;
    final trackWidth = tester.getSize(track.first).width;
    expect(halfwayWidth, greaterThan(0));
    expect(halfwayWidth, lessThan(trackWidth / 2));
    await tester.pump(const Duration(milliseconds: 225));
    expect(tester.getSize(fill).width, closeTo(trackWidth / 2, 1));
  });

  testWidgets('seeding age progress animates over HIG duration', (
    tester,
  ) async {
    final batch = SeedingBatch(
      id: '1',
      batchName: 'Batch 1',
      variety: 'Selada',
      dateText: '2026-10-01',
      seedCount: 100,
      hss: 7,
      totalHss: 15,
      statusLabel: 'Aktif',
    );
    await tester.pumpWidget(
      MaterialApp(home: InfoSeedingPage(seedingItem: batch)),
    );
    await tester.pump(const Duration(milliseconds: 225));
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, greaterThan(0));
    expect(progress.value, lessThan(7 / 15));
    await tester.pump(const Duration(milliseconds: 225));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(7 / 15, 0.001),
    );
  });
}
