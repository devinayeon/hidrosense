import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/table_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/damage_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/detail_tanaman_meja_body.dart';
import 'support/damage_fixture.dart';

void main() {
  testWidgets(
    'note dialog guards saving, retries uncertainty and permits Escape',
    (tester) async {
      final api = apiFor((_) async => throw StateError('Unexpected API'));
      addTearDown(api.close);
      final repo = FakeDamageRepository(api);
      final pending = Completer<TransferRecord>();
      repo.onUpdateTransfer = (_, _) => pending.future;
      final vm = DamageViewModel(repo, '1', () async {}, canWrite: true);
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
          child: const MaterialApp(
            home: Scaffold(
              body: DetailTanamanMejaBody(
                table: TableRecord(
                  id: '1',
                  code: 'M-01',
                  holeCount: 250,
                  status: 'tersedia',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final edit = find.widgetWithIcon(IconButton, Icons.edit_note_rounded);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Catatan tersimpan');
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repo.editKeys, hasLength(1));
      pending.completeError(const ApiException(0, 'NETWORK', 'Offline'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Offline'),
        ),
        findsOneWidget,
      );
      repo.onUpdateTransfer = (_, note) async {
        final saved = TransferRecord.fromJson({
          ...transferJson(),
          'keterangan': note,
          'version': '2',
        });
        repo.transfers = [saved];
        return saved;
      };
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.editKeys, hasLength(2));
      expect(repo.editKeys[0], repo.editKeys[1]);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
