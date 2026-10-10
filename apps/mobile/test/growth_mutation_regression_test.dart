import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/damage_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/repositories/nursery_repository.dart';
import 'package:hidrosense_mobile/data/repositories/table_repository.dart';
import 'package:hidrosense_mobile/viewmodels/connected_nursery_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/connected_table_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/damage_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'support/damage_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'damage receipt cannot overwrite newer reports or same-version fresh active count',
    () async {
      final api = apiFor((_) async => throw StateError('Unexpected'));
      final repo = FakeDamageRepository(api);
      final vm = DamageViewModel(
        repo,
        '1',
        () async {},
        canWrite: true,
        autoLoad: false,
      );
      addTearDown(vm.dispose);
      addTearDown(api.close);
      repo.reports = [
        DamageRecord.fromJson({
          ...damageJson(),
          'version': '3',
          'keterangan': 'Latest',
        }),
      ];
      repo.onUpdateDamage = (id, {date, plantCount, category, note}) async =>
          DamageRecord.fromJson({
            ...damageJson(),
            'version': '2',
            'keterangan': 'Old replay',
          });
      await vm.refresh();
      await vm.updateDamage('1', note: 'Old replay');
      expect(vm.state.reports['1']!.single.note, 'Latest');
      repo.onUpdateTransfer = (id, note) async {
        repo.transfers = [
          TransferRecord.fromJson({
            ...transferJson(active: 195),
            'version': '2',
            'keterangan': note,
          }),
        ];
        return TransferRecord.fromJson({
          ...transferJson(active: 200),
          'version': '2',
          'keterangan': note,
        });
      };
      await vm.updateTransfer('1', note: 'Note');
      expect(vm.state.transfers.single.activePlants, 195);
    },
  );
  test('table receipt cannot overwrite post-write aggregate balance', () async {
    Map<String, dynamic> table(int active) => {
      'id_meja': '1',
      'kode_meja': 'M-01',
      'jumlah_lubang': 250,
      'tanaman_aktif': active,
      'version': '2',
    };
    final api = apiFor(
      (r) async => r.method == 'PATCH'
          ? reply({'data': table(0)})
          : reply({
              'data': [table(5)],
              'meta': {'page': 1, 'limit': 50, 'total': 1, 'total_pages': 1},
            }),
    );
    final vm = ConnectedTableNotifier(TableRepository(api));
    addTearDown(vm.dispose);
    addTearDown(api.close);
    await vm.updateTable('1', code: 'M-01');
    expect(vm.state.records.single.activePlants, 5);
  });
  test(
    'wrong table receipt is not cached and retry sends same key again',
    () async {
      final keys = <String>[];
      final api = apiFor((r) async {
        if (r.method == 'PATCH') {
          keys.add(r.headers['Idempotency-Key']!);
          return reply({
            'data': {
              'id_meja': keys.length == 1 ? '2' : '1',
              'kode_meja': 'M-01',
              'jumlah_lubang': 250,
              'version': '2',
            },
          });
        }
        return reply({
          'data': [],
          'meta': {'page': 1, 'limit': 50, 'total': 0, 'total_pages': 0},
        });
      });
      final vm = ConnectedTableNotifier(TableRepository(api));
      addTearDown(vm.dispose);
      addTearDown(api.close);
      await expectLater(
        vm.updateTable('1', notes: null),
        throwsFormatException,
      );
      expect(vm.pendingCommand!.receipt, isNull);
      await vm.updateTable('1', notes: null);
      expect(keys, hasLength(2));
      expect(keys[0], keys[1]);
    },
  );
  test(
    'transfer receipt must match sowing, table, date and quantity',
    () async {
      final api = apiFor(
        (r) async => reply({
          'data': {...transferJson(), 'id_meja': '2'},
        }),
      );
      addTearDown(api.close);
      await expectLater(
        NurseryRepository(api).transferSowing(
          idempotencyKey: '22222222-2222-4222-8222-222222222222',
          sowingId: '1',
          tableId: '1',
          transferDate: '2026-09-16',
          plantCount: 200,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'post-transfer refresh waits for the earlier read then reads fresh data',
    () async {
      final earlier = Completer<http.Response>();
      var reads = 0;
      Map<String, dynamic> sow(int remaining) => {
        'id_penyemaian': '1',
        'id_user': '1',
        'tanggal_semai': '2026-09-01',
        'jumlah_benih': 600,
        'sisa_benih': remaining,
        'status_penyemaian': 'aktif',
      };
      http.Response page(int remaining) => reply({
        'data': [sow(remaining)],
        'meta': {'page': 1, 'total': 1, 'total_pages': 1},
      });
      final api = apiFor(
        (_) async => ++reads == 1 ? earlier.future : page(350),
      );
      addTearDown(api.close);
      final vm = ConnectedNurseryViewModel(NurseryRepository(api));
      addTearDown(vm.dispose);
      var done = false;
      final refreshed = vm.refreshAfterTransfer().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);
      expect(done, isFalse);
      earlier.complete(page(600));
      await refreshed;
      expect(reads, 2);
      expect(vm.state.records.single.remainingSeedCount, 350);
    },
  );
  testWidgets(
    'Jakarta midnight and resume reload ages; disposal cancels timer',
    (tester) async {
      final api = apiFor((_) async => throw StateError('Unexpected'));
      addTearDown(api.close);
      final repo = FakeDamageRepository(api);
      var calls = 0;
      repo.onList = () async {
        calls++;
        return [
          TransferRecord.fromJson({...transferJson(), 'hss': 20 + calls}),
        ];
      };
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var now = DateTime.utc(2026, 10, 9, 16, 59, 59);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          damageRepositoryProvider.overrideWithValue(repo),
          growthClockProvider.overrideWithValue(() => now),
          sessionProvider.overrideWith(
            (_) => SessionViewModel(
              api,
              initialState: const SessionState(user: farmer),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(damageProvider('1'), (_, _) {});
      await tester.pump();
      expect(calls, 1);
      now = DateTime.utc(2026, 10, 9, 17);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 3);
      final old = container.read(damageProvider('1').notifier);
      listener.close();
      container.invalidate(damageProvider('1'));
      await tester.pump();
      expect(old.mounted, isFalse);
      await tester.pump(const Duration(days: 1));
      expect(calls, 3);
    },
  );
}
