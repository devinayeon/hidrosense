import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/table_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/models/damage_record.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/viewmodels/damage_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/meja_nft_page.dart';
import 'package:hidrosense_mobile/views/pages/form_meja_nft_page.dart';
import 'package:hidrosense_mobile/views/pages/info_meja_page.dart';
import 'package:hidrosense_mobile/views/pages/detail_tanaman_meja_page.dart';
import 'package:hidrosense_mobile/views/pages/catat_kerusakan_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/seedling_transfer_sheet.dart';
import 'support/damage_fixture.dart';
import 'support/remediation_capture.dart';

const table = TableRecord(
  id: '1',
  code: 'M-0123456789012345678901234567',
  holeCount: 250,
  status: 'perbaikan',
  activePlants: 195,
  notes: 'Spesifikasi pompa dan pipa meja tanam.',
);
void main() {
  setUpAll(loadCaptureFonts);
  for (final dark in [false, true]) {
    for (final screen in [
      'list',
      'detail',
      'create',
      'edit',
      'batch',
      'damage-edit',
      'note',
      'loading',
      'empty',
      'error',
      'transfer',
      'transfer-date',
      'damage-date',
      'edit-keyboard',
      'damage-keyboard',
    ]) {
      testWidgets('$screen 320x568 text2 ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = apiFor(
          (request) async => reply({
            'data': request.url.path.contains('penyemaian')
                ? <Object>[]
                : [
                    {
                      ...table.toJson(),
                      if (screen.startsWith('transfer'))
                        'status_meja': 'tersedia',
                      if (screen.startsWith('transfer'))
                        'kapasitas_tersedia': 55,
                    },
                  ],
            'meta': {
              'page': 1,
              'limit': 50,
              'total': request.url.path.contains('penyemaian') ? 0 : 1,
              'total_pages': request.url.path.contains('penyemaian') ? 0 : 1,
            },
          }),
        );
        addTearDown(api.close);
        final repo = FakeDamageRepository(api);
        repo.transfers = [
          TransferRecord.fromJson({
            ...transferJson(),
            'hss': 38,
            'hst': 23,
            'sisa_hari_panen': 7,
            'estimasi_panen': '2026-10-16',
            'keterangan': 'Periksa nutrisi dan kondisi tanaman.',
          }),
        ];
        repo.reports = [
          DamageRecord.fromJson({
            ...damageJson(),
            'jenis_kerusakan': 'Kategori tersimpan di luar preset',
            'keterangan': 'Catatan kerusakan yang tersimpan.',
          }),
        ];
        final vm = DamageViewModel(
          repo,
          '1',
          () async {},
          canWrite: true,
          autoLoad: false,
        );
        if (screen == 'empty') {
          repo.transfers = [];
        }
        if (screen == 'error') {
          repo.loadError = StateError('Koneksi terputus.');
        }
        if (screen == 'loading') {
          repo.onList = () => Completer<List<TransferRecord>>().future;
          unawaited(vm.refresh());
        } else {
          await vm.refresh();
        }
        final Widget page = switch (screen) {
          'list' => const MejaNftPage(),
          'detail' => const InfoMejaPage(tableRecord: table),
          'create' => const FormMejaNftPage(),
          'edit' ||
          'edit-keyboard' => const FormMejaNftPage(tableRecord: table),
          'damage-edit' ||
          'damage-date' ||
          'damage-keyboard' => CatatKerusakanPage(
            table: table,
            initialTransfer: repo.transfers.first,
            damageRecordToEdit: repo.reports.first,
          ),
          'transfer' || 'transfer-date' => Scaffold(
            body: SeedlingTransferSheet(
              onTransferred: () {},
              sowingRecord: const SowingRecord(
                id: '1',
                userId: '1',
                sowingDate: '2026-09-01',
                seedCount: 600,
                status: 'aktif',
                ageDays: 20,
                isReadyToMove: true,
              ),
            ),
          ),
          _ => const DetailTanamanMejaPage(table: table),
        };
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              sessionProvider.overrideWith(
                (_) => SessionViewModel(
                  api,
                  initialState: SessionState(
                    user: SessionUser(
                      id: farmer.id,
                      name: farmer.name,
                      username: farmer.username,
                      role: farmer.role,
                      permissions: [...farmer.permissions, 'penyemaian:write'],
                    ),
                  ),
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
                  data: MediaQueryData(
                    size: Size(320, 568),
                    textScaler: TextScaler.linear(2),
                    viewInsets: EdgeInsets.only(
                      bottom: screen.endsWith('-keyboard') ? 360 : 0,
                    ),
                  ),
                  child: child!,
                ),
              ),
              home: page,
            ),
          ),
        );
        if (screen == 'loading') {
          await tester.pump(const Duration(milliseconds: 400));
        } else {
          await tester.pumpAndSettle();
        }
        if (screen == 'note') {
          await tester.tap(
            find.widgetWithIcon(IconButton, Icons.edit_note_rounded),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.enterText(
            find.byType(TextField).last,
            'Catatan diperbaiki',
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        if (screen.startsWith('damage')) {
          expect(find.text('Kategori tersimpan di luar preset'), findsWidgets);
          expect(
            tester
                .widget<DropdownButtonFormField<String>>(
                  find.byType(DropdownButtonFormField<String>).first,
                )
                .onChanged,
            isNull,
          );
          await tester.enterText(find.byType(TextFormField).first, '3');
        }
        if (screen.startsWith('transfer')) {
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.textContaining('(55 tersedia)').last);
          await tester.pumpAndSettle();
        }
        if (screen.endsWith('-date')) {
          final date = find.textContaining(
            screen.startsWith('transfer')
                ? 'Tanggal pemindahan:'
                : 'Tanggal kejadian:',
          );
          await tester.ensureVisible(date);
          await tester.tap(date);
          await tester.pumpAndSettle();
          expect(find.byType(DatePickerDialog), findsOneWidget);
        }
        if (screen.endsWith('-keyboard')) {
          await tester.enterText(find.byType(TextFormField).last, 'Catatan');
          await tester.ensureVisible(find.byType(EditableText).last);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byType(EditableText).last).bottom,
            lessThanOrEqualTo(208),
          );
        }
        await captureRemediation(
          tester,
          'growth-$screen-${dark ? 'dark' : 'light'}-320-text2',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
