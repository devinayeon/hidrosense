import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/damage_record.dart';
import 'package:hidrosense_mobile/data/models/table_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/viewmodels/damage_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/detail_tanaman_meja_body.dart';
import 'package:hidrosense_mobile/views/pages/catat_kerusakan_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'support/damage_fixture.dart';
import 'support/remediation_capture.dart';

const table = TableRecord(
  id: '1',
  code: 'M-01',
  holeCount: 250,
  status: 'tersedia',
  activePlants: 200,
);

void main() {
  setUpAll(loadCaptureFonts);
  testWidgets('batch list exposes loading, error retry, and empty states', (
    tester,
  ) async {
    final api = apiFor((_) async => throw StateError('Unexpected API'));
    addTearDown(api.close);
    final repo = FakeDamageRepository(api);
    final pending = Completer<List<dynamic>>();
    repo.onList = () async {
      await pending.future;
      throw StateError('Offline');
    };
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
          damageProvider('1').overrideWith(
            (_) => DamageViewModel(repo, '1', () async {}, canWrite: true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: DetailTanamanMejaBody(table: table)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Coba lagi'), findsOneWidget);
    repo.onList = () async => [];
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada batch pemindahan pada meja ini.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'form blocks dismissal during POST and shows saved refresh warning',
    (tester) async {
      final api = apiFor((_) async => throw StateError('Unexpected API'));
      addTearDown(api.close);
      final repo = FakeDamageRepository(api);
      final pending = Completer<DamageRecord>();
      repo.onCreate = (_, _) => pending.future;
      final vm = DamageViewModel(
        repo,
        '1',
        () async => throw StateError('Refresh failed'),
        canWrite: true,
        autoLoad: false,
      );
      await vm.refresh();
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
            damageProvider('1').overrideWith((_) => vm),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) => CatatKerusakanPage(
                        table: table,
                        initialTransfer: repo.transfers.single,
                      ),
                    ),
                  ),
                  child: const Text('Buka form'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka form'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.enterText(find.byType(TextFormField).last, 'Catatan tetap');
      await tester.ensureVisible(find.text('Simpan Laporan Kerusakan'));
      await tester.tap(find.text('Simpan Laporan Kerusakan'));
      await tester.pump();
      expect(find.text('Menyimpan laporan...'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(CatatKerusakanPage), findsOneWidget);
      pending.complete(DamageRecord.fromJson(damageJson()));
      await tester.pumpAndSettle();
      expect(find.byType(CatatKerusakanPage), findsNothing);
      expect(find.textContaining('Tersimpan.'), findsOneWidget);
      expect(repo.keys.length, 1);
      expect(repo.drafts.single.note, 'Catatan tetap');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uncertain save keeps fields and permits exact replay after reload reaches zero capacity',
    (tester) async {
      final api = apiFor((_) async => throw StateError('Unexpected API'));
      addTearDown(api.close);
      final repo = FakeDamageRepository(api);
      repo.onCreate = (_, _) async {
        if (repo.keys.length == 1) {
          repo.transfers = [TransferRecord.fromJson(transferJson(active: 0))];
          throw TimeoutException('Response lost after commit');
        }
        return DamageRecord.fromJson(damageJson());
      };
      final vm = DamageViewModel(
        repo,
        '1',
        () async {},
        canWrite: true,
        autoLoad: false,
      );
      await vm.refresh();
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
            damageProvider('1').overrideWith((_) => vm),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) => CatatKerusakanPage(
                        table: table,
                        initialTransfer: repo.transfers.single,
                      ),
                    ),
                  ),
                  child: const Text('Buka form'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka form'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.enterText(find.byType(TextFormField).last, 'Respons hilang');
      await tester.ensureVisible(find.text('Simpan Laporan Kerusakan'));
      await tester.tap(find.text('Simpan Laporan Kerusakan'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Muat ulang batch'));
      await tester.tap(find.text('Muat ulang batch'));
      await tester.pumpAndSettle();
      expect(find.textContaining('0 tanaman aktif dari 200'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '5',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        'Respons hilang',
      );
      await tester.ensureVisible(find.text('Simpan Laporan Kerusakan'));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Simpan Laporan Kerusakan'));
      await tester.pumpAndSettle();
      expect(repo.keys.length, 2);
      expect(repo.keys[0], repo.keys[1]);
      expect(find.text('Buka form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'damage form supports small screen, large text, keyboard and ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = apiFor((_) async => throw StateError('Unexpected API'));
        addTearDown(api.close);
        final repo = FakeDamageRepository(api);
        final vm = DamageViewModel(
          repo,
          '1',
          () async {},
          canWrite: true,
          autoLoad: false,
        );
        await vm.refresh();
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
              damageProvider('1').overrideWith((_) => vm),
            ],
            child: MaterialApp(
              theme: dark
                  ? ThemeData.dark(useMaterial3: true)
                  : AppTheme.lightTheme,
              builder: (_, child) => RepaintBoundary(
                key: const ValueKey('remediation-capture'),
                child: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(320, 568),
                    textScaler: TextScaler.linear(2),
                  ),
                  child: child!,
                ),
              ),
              home: CatatKerusakanPage(
                table: table,
                initialTransfer: repo.transfers.single,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await captureRemediation(
          tester,
          dark ? 'damage-dark-large-text' : 'damage-light-large-text',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        expect(FocusManager.instance.primaryFocus, isNotNull);
        await tester.enterText(find.byType(TextFormField).first, '201');
        await tester.ensureVisible(find.text('Simpan Laporan Kerusakan'));
        final save = find.widgetWithText(
          FilledButton,
          'Simpan Laporan Kerusakan',
        );
        expect(tester.getSize(save).height, greaterThanOrEqualTo(44));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('Jumlah harus 1 sampai 200 tanaman.'), findsOneWidget);
        await captureRemediation(
          tester,
          dark ? 'damage-dark-validation' : 'damage-light-validation',
        );
        expect(repo.keys, isEmpty);
        expect(find.textContaining('FOTO'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
