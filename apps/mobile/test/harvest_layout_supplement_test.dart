import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/harvest_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/panen_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/laporan_panen_page.dart';
import 'package:hidrosense_mobile/views/pages/panen_form_page.dart';
import 'package:hidrosense_mobile/views/pages/panen_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'support/harvest_fixture.dart';

void main() {
  for (final dark in [false, true]) {
    for (final screen in [
      'detail',
      'correction-keyboard',
      'detail-loading',
      'detail-error',
      'correction-loading',
      'correction-error',
      'list-loading',
      'dropdown',
    ]) {
      testWidgets(
        '$screen at 320x568 text2 ${dark ? 'dark' : 'light'} remains usable',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            final api = harvestApi((_) async => harvestPage([]));
            addTearDown(api.close);
            final repo = FakeHarvestRepository(api);
            repo.records = [
              HarvestRecord.fromJson(
                harvestJson(note: 'Catatan sortasi tersimpan.'),
              ),
            ];
            final vm = harvestVm(repo);
            await vm.refresh();
            final waiting = Completer<HarvestRecord>();
            if (screen.endsWith('loading') && screen != 'list-loading') {
              repo.onDetail = (_) => waiting.future;
            }
            if (screen.endsWith('error')) {
              repo.detailError = const ApiException(
                503,
                'READ',
                'Laporan gagal dimuat.',
              );
            }
            final pendingList = Completer<List<HarvestRecord>>();
            if (screen == 'list-loading') {
              repo.onRead = () => pendingList.future;
              unawaited(vm.refresh());
            }
            final Widget page = screen == 'list-loading'
                ? const PanenPage()
                : screen == 'dropdown'
                ? const PanenFormPage(transferId: '1')
                : screen.startsWith('correction')
                ? const PanenFormPage(harvestId: '1')
                : const LaporanPanenPage(harvestId: '1');
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  apiClientProvider.overrideWithValue(api),
                  sessionProvider.overrideWith(
                    (_) => SessionViewModel(
                      api,
                      initialState: const SessionState(user: harvestUser),
                    ),
                  ),
                  harvestRepositoryProvider.overrideWithValue(repo),
                  panenViewModelProvider.overrideWith((_) => vm),
                ],
                child: MaterialApp(
                  theme: dark
                      ? ThemeData.dark(useMaterial3: true)
                      : AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: page,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (screen.endsWith('loading')) {
              expect(find.textContaining('Memuat'), findsWidgets);
              expect(find.text('Layak jual: 2.25 kg'), findsNothing);
            } else if (screen.endsWith('error')) {
              expect(find.text('Laporan gagal dimuat.'), findsOneWidget);
              final retry = find.widgetWithText(TextButton, 'Coba lagi');
              expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
              expect(tester.getSemantics(retry).label, contains('Coba lagi'));
              repo.detailError = null;
              await tester.tap(retry);
              await tester.pumpAndSettle();
              expect(find.text('Laporan gagal dimuat.'), findsNothing);
            } else if (screen == 'detail') {
              expect(find.text('Layak jual: 2.25 kg'), findsOneWidget);
              final correction = find.widgetWithText(
                FilledButton,
                'Koreksi Sortasi atau Catatan',
              );
              await tester.scrollUntilVisible(
                correction,
                180,
                scrollable: find.byType(Scrollable).first,
              );
              expect(
                tester.getSize(correction).height,
                greaterThanOrEqualTo(48),
              );
              expect(
                tester.getSemantics(correction).label,
                contains('Koreksi Sortasi atau Catatan'),
              );
              await tester.tap(correction);
              await tester.pumpAndSettle();
              expect(find.text('Koreksi berat sortasi'), findsOneWidget);
            } else if (screen == 'correction-keyboard') {
              final toggle = find.byType(Switch);
              await tester.scrollUntilVisible(
                toggle,
                100,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              await tester.tap(toggle);
              await tester.pumpAndSettle();
              expect(tester.widget<Switch>(toggle).value, isTrue);
              expect(
                find.widgetWithText(TextField, 'Jumlah'),
                findsNothing,
              );
              expect(
                find.byType(DropdownButtonFormField<String>),
                findsNothing,
              );
              final note = find.widgetWithText(TextField, 'Catatan panen');
              await tester.scrollUntilVisible(
                note,
                180,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.enterText(note, 'Koreksi catatan');
              tester.view.viewInsets = const FakeViewPadding(bottom: 220);
              addTearDown(tester.view.resetViewInsets);
              await tester.pumpAndSettle();
              final save = find.widgetWithText(FilledButton, 'Simpan Koreksi');
              await tester.scrollUntilVisible(
                save,
                100,
                scrollable: find.byType(Scrollable).first,
              );
              await Scrollable.ensureVisible(
                tester.element(save),
                alignment: 1,
              );
              await tester.pumpAndSettle();
              expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
              expect(
                tester.getSemantics(save).label,
                contains('Simpan Koreksi'),
              );
              expect(
                tester.getRect(save).bottom,
                lessThanOrEqualTo(568 - 220 + 0.01),
              );
              await tester.tap(save);
              await tester.pumpAndSettle();
              expect(repo.bodies.single['keterangan'], 'Koreksi catatan');
              expect(repo.bodies.single['details'], [
                {
                  'id_detail_panen': '1',
                  'berat_total': '2.50',
                  'berat_reject': '0.25',
                },
              ]);
            } else if (screen == 'dropdown') {
              final dropdown = find.byType(DropdownButtonFormField<String>);
              await tester.scrollUntilVisible(
                dropdown,
                150,
                scrollable: find.byType(Scrollable).first,
              );
              expect(tester.getSize(dropdown).height, greaterThanOrEqualTo(48));
              expect(
                tester.getSemantics(dropdown).label,
                contains('Pilih batch aktif'),
              );
              await tester.tap(dropdown);
              await tester.pumpAndSettle();
              final item = find.text('#1 • Meja #1').last;
              expect(
                tester
                    .getSize(
                      find
                          .ancestor(of: item, matching: find.byType(InkWell))
                          .first,
                    )
                    .height,
                greaterThanOrEqualTo(48),
              );
              await tester.tap(item);
              await tester.pumpAndSettle();
              expect(find.textContaining('200 tanaman aktif'), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            if (screen == 'list-loading') pendingList.complete([]);
            if (screen.endsWith('loading') && screen != 'list-loading') {
              waiting.complete(repo.records.first);
            }
            await tester.pumpAndSettle();
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
