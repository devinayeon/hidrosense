import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/harvest_draft.dart';
import 'package:hidrosense_mobile/data/models/harvest_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/panen_viewmodel.dart';
import 'support/harvest_fixture.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hidrosense_mobile/viewmodels/connected_table_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/damage_viewmodel.dart'
    show growthClockProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<(FakeHarvestRepository, PanenViewModel)> setup({
    HarvestCommands? commands,
  }) async {
    final repo = await loadedRepo();
    final vm = harvestVm(repo, commands: commands);
    addTearDown(() {
      vm.dispose();
    });
    await vm.refresh();
    return (repo, vm);
  }

  test(
    'double submit locks before await and refreshes harvest/batches/table exactly once',
    () async {
      final repo = await loadedRepo();
      final complete = Completer<HarvestRecord>();
      repo.onWrite = (_, _, _) => complete.future;
      var tables = 0;
      final vm = harvestVm(
        repo,
        tables: (ids) async {
          tables++;
          expect(ids, {'1'});
        },
      );
      addTearDown(vm.dispose);
      await vm.refresh();
      final save = vm.submit(harvestDraft);
      expect(vm.current.submitting, true);
      expect(await vm.submit(harvestDraft), HarvestSubmitResult.busy);
      complete.complete(HarvestRecord.fromJson(harvestJson()));
      expect(await save, HarvestSubmitResult.saved);
      expect(repo.keys.length, 1);
      expect(repo.harvestReads, 2);
      expect(repo.transferReads, 2);
      expect(tables, 1);
    },
  );
  test(
    'uncertain network reuses UUID/payload, prevents another form, then permits new draft',
    () async {
      final (repo, vm) = await setup();
      repo.onWrite = (_, _, _) async => throw TimeoutException('lost receipt');
      expect(await vm.submit(harvestDraft), HarvestSubmitResult.failed);
      expect(vm.payloadLocked, true);
      final firstKey = repo.keys.single;
      expect(
        await vm.submit(
          const HarvestDraft(date: '2026-10-10', note: 'changed', rows: []),
        ),
        HarvestSubmitResult.failed,
      );
      expect(repo.keys.length, 1);
      repo.onWrite = (_, _, _) async => HarvestRecord.fromJson(harvestJson());
      expect(await vm.retryPending(), HarvestSubmitResult.saved);
      expect(repo.keys, [firstKey, firstKey]);
      vm.beginDraft();
      expect(await vm.submit(harvestDraft), HarvestSubmitResult.saved);
      expect(repo.keys.last, isNot(firstKey));
    },
  );
  test(
    'saved refresh failure retains receipt; manual refresh only GET never resends',
    () async {
      final (repo, vm) = await setup();
      repo.onWrite = (_, _, _) async {
        repo.readError = const ApiException(503, 'READ', 'read failed');
        return HarvestRecord.fromJson(harvestJson());
      };
      expect(
        await vm.submit(harvestDraft),
        HarvestSubmitResult.savedRefreshFailed,
      );
      expect(vm.current.records.single.id, '1');
      expect(vm.current.refreshWarning, contains('Tersimpan'));
      await vm.refresh();
      expect(repo.keys.length, 1);
      expect(vm.current.records.single.id, '1');
    },
  );
  test(
    'slow prewrite GET cannot overwrite receipt and equal/lower versions remain cached',
    () async {
      final (repo, vm) = await setup();
      final read = Completer<List<HarvestRecord>>();
      repo.onRead = () => read.future;
      final staleRead = vm.refresh();
      repo.onRead = null;
      repo.onWrite = (_, _, _) async =>
          HarvestRecord.fromJson(harvestJson(version: '3'));
      expect(await vm.submit(harvestDraft), HarvestSubmitResult.saved);
      read.complete([HarvestRecord.fromJson(harvestJson())]);
      await staleRead;
      expect(vm.current.records.single.version, '3');
      repo.records = [
        HarvestRecord.fromJson(harvestJson(version: '3', note: 'equal stale')),
      ];
      await vm.refresh();
      expect(vm.current.records.single.note, isNull);
      repo.records = [
        HarvestRecord.fromJson(harvestJson(version: '4', note: 'newer')),
      ];
      await vm.refresh();
      expect(vm.current.records.single.note, 'newer');
    },
  );
  test(
    'dispose while request waits stores receipt before mounted check and releases lock',
    () async {
      final repo = await loadedRepo();
      final commands = HarvestCommands();
      final vm = harvestVm(repo, commands: commands);
      await vm.refresh();
      final complete = Completer<HarvestRecord>();
      repo.onWrite = (_, _, _) => complete.future;
      final save = vm.submit(harvestDraft);
      vm.dispose();
      complete.complete(HarvestRecord.fromJson(harvestJson()));
      expect(await save, HarvestSubmitResult.saved);
      expect(commands.pending.values.single.running, false);
      expect(commands.receipts.values.single['1']?.id, '1');
      final restored = harvestVm(repo, commands: commands);
      addTearDown(restored.dispose);
      await restored.refresh();
      expect(restored.current.records.single.id, '1');
    },
  );
  test(
    'same account recreates uncertain command; other account/server cannot see or send it',
    () async {
      final repo = await loadedRepo();
      final commands = HarvestCommands();
      var vm = harvestVm(repo, commands: commands);
      await vm.refresh();
      repo.onWrite = (_, _, _) async =>
          throw const ApiException(401, 'SESSION_CHANGED', 'session changed');
      await vm.submit(harvestDraft);
      final key = repo.keys.single;
      vm.dispose();
      final other = harvestVm(repo, commands: commands, userId: '2');
      addTearDown(other.dispose);
      expect(other.pendingCommand, isNull);
      final anotherServer = FakeHarvestRepository(
        harvestApi((_) async => harvestPage([]), server: 'other.test'),
      );
      final remote = harvestVm(anotherServer, commands: commands);
      addTearDown(remote.dispose);
      expect(remote.pendingCommand, isNull);
      vm = harvestVm(repo, commands: commands);
      addTearDown(vm.dispose);
      await vm.refresh();
      expect(vm.pendingCommand!.key, key);
      expect(vm.payloadLocked, true);
      repo.onWrite = (_, _, _) async => HarvestRecord.fromJson(harvestJson());
      await vm.retryPending();
      expect(repo.keys, [key, key]);
    },
  );
  test(
    'version conflict reloads, preserves correction, demands explicit review and fresh UUID',
    () async {
      final (repo, vm) = await setup();
      repo.records = [HarvestRecord.fromJson(harvestJson())];
      await vm.refresh();
      repo.onWrite = (_, _, _) async {
        repo.records = [HarvestRecord.fromJson(harvestJson(version: '2'))];
        throw const ApiException(
          409,
          'HARVEST_VERSION_CONFLICT',
          'version changed',
        );
      };
      const correction = HarvestCorrection(
        id: '1',
        expectedVersion: '1',
        note: 'my note',
      );
      expect(await vm.correct(correction), HarvestSubmitResult.failed);
      expect(vm.current.conflictId, '1');
      expect(
        await vm.correct(
          const HarvestCorrection(
            id: '1',
            expectedVersion: '2',
            note: 'my note',
          ),
        ),
        HarvestSubmitResult.failed,
      );
      expect(repo.keys.length, 1);
      vm.acknowledgeConflict('1');
      repo.onWrite = null;
      expect(
        await vm.correct(
          const HarvestCorrection(
            id: '1',
            expectedVersion: '2',
            note: 'my note',
          ),
        ),
        HarvestSubmitResult.saved,
      );
      expect(repo.keys[0], isNot(repo.keys[1]));
      expect(repo.bodies.last['keterangan'], 'my note');
    },
  );
  test(
    'legacy notes only and explicit null; both sortation weights needed to correct',
    () async {
      final (repo, vm) = await setup();
      repo.records = [HarvestRecord.fromJson(harvestJson(legacy: true))];
      await vm.refresh();
      expect(
        await vm.correct(
          const HarvestCorrection(
            id: '1',
            expectedVersion: '1',
            rows: [
              HarvestCorrectionRow(detailId: '1', total: '2.5', reject: ''),
            ],
          ),
        ),
        HarvestSubmitResult.failed,
      );
      expect(repo.keys, isEmpty);
      expect(
        await vm.correct(
          const HarvestCorrection(id: '1', expectedVersion: '1', note: ' '),
        ),
        HarvestSubmitResult.saved,
      );
      expect(repo.bodies.single['keterangan'], isNull);
      expect(repo.bodies.single.containsKey('details'), false);
    },
  );
  test(
    'multi batch validations reject duplicates, overcapacity, dates, reject and too many rows',
    () async {
      final (_, vm) = await setup();
      final row = harvestDraft.rows.single;
      expect(
        vm.validateDraft(
          HarvestDraft(date: harvestDraft.date, rows: [row, row]),
        ),
        isNotNull,
      );
      expect(
        vm.validateDraft(const HarvestDraft(date: '2026-10-11', rows: [])),
        isNotNull,
      );
      expect(
        vm.validateDraft(
          const HarvestDraft(
            date: '2026-09-15',
            rows: [
              HarvestDraftRow(
                transferId: '1',
                plantCount: 201,
                total: '2',
                reject: '3',
              ),
            ],
          ),
        ),
        isNotNull,
      );
      expect(
        vm.validateDraft(
          HarvestDraft(date: harvestDraft.date, rows: List.filled(101, row)),
        ),
        isNotNull,
      );
      expect(vm.validateDraft(harvestDraft), isNull);
    },
  );
  test(
    'read permission batch guard does not fetch transfers, write guard does not mutate',
    () async {
      final repo = await loadedRepo();
      final vm = harvestVm(repo, canWrite: false, canReadBatches: false);
      addTearDown(vm.dispose);
      await vm.refresh();
      expect(repo.transferReads, 0);
      expect(await vm.submit(harvestDraft), HarvestSubmitResult.failed);
      expect(repo.keys, isEmpty);
    },
  );
  test(
    'detail authoritative 404 removes cached target without deleting other records',
    () async {
      final (repo, vm) = await setup();
      repo.records = [
        HarvestRecord.fromJson(harvestJson()),
        HarvestRecord.fromJson(harvestJson(id: '2')),
      ];
      await vm.refresh();
      repo.detailError = const ApiException(
        404,
        'HARVEST_NOT_FOUND',
        'Data panen tidak ditemukan.',
      );
      await vm.loadDetail('1');
      expect(vm.current.records.map((r) => r.id), ['2']);
      expect(vm.current.error, contains('tidak ditemukan'));
    },
  );
  test(
    'remaining active zero after uncertain create still resolves identical command',
    () async {
      final (repo, vm) = await setup();
      repo.onWrite = (_, _, _) async => throw TimeoutException('lost');
      await vm.submit(harvestDraft);
      repo.transfers = [
        TransferRecord.fromJson(harvestTransferJson(active: 0)),
      ];
      await vm.refresh();
      repo.onWrite = (_, _, _) async => HarvestRecord.fromJson(harvestJson());
      expect(await vm.retryPending(), HarvestSubmitResult.saved);
      expect(repo.bodies[0], repo.bodies[1]);
    },
  );
  test(
    'provider refreshes each actual connected table cache once for multiple deduplicated affected tables',
    () async {
      final detailGets = <String>[];
      Map<String, dynamic> table(String id, int active) => {
        'id_meja': id,
        'kode_meja': 'NFT-$id',
        'jumlah_lubang': 250,
        'status_meja': 'tersedia',
        'keterangan': null,
        'tanaman_aktif': active,
        'kapasitas_tersedia': 250 - active,
        'version': '2',
        'public_id': '79464d5b-b494-48a5-9727-7b2b13dc4e35',
      };
      final api = harvestApi((request) async {
        if (request.url.path.endsWith('meja-tanam')) {
          return harvestReply({
            'data': [table('1', 200), table('2', 200)],
            'meta': {'page': 1, 'limit': 50, 'total': 2, 'total_pages': 1},
          });
        }
        final id = request.url.path.split('/').last;
        detailGets.add(id);
        await Future<void>.delayed(Duration.zero);
        return harvestReply({'data': table(id, id == '1' ? 190 : 195)});
      });
      addTearDown(api.close);
      final repo = FakeHarvestRepository(api);
      repo.transfers = [
        for (final id in ['1', '2', '3'])
          TransferRecord.fromJson({
            ...harvestTransferJson(id: id),
            'id_meja': id == '2' ? '2' : '1',
          }),
      ];
      final snapshot = harvestJson();
      final first =
          (snapshot['details'] as List).single as Map<String, dynamic>;
      snapshot['details'] = [
        for (final id in ['1', '2', '3'])
          {
            ...first,
            'id_detail_panen': id,
            'id_pemindahan': id,
            'id_meja': id == '2' ? '2' : '1',
          },
      ];
      snapshot['berat_total'] = '7.50';
      snapshot['berat_reject'] = '0.75';
      snapshot['berat_layak'] = '6.75';
      repo.onWrite = (_, _, _) async => HarvestRecord.fromJson(snapshot);
      final container = ProviderContainer(
        overrides: [
          growthClockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 10)),
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith(
            (ref) => SessionViewModel(
              api,
              initialState: const SessionState(user: harvestUser),
            ),
          ),
          harvestRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final tableListener = container.listen(connectedTableProvider, (_, _) {});
      addTearDown(tableListener.close);
      await container.read(connectedTableProvider.notifier).refresh();
      final harvestListener = container.listen(
        panenViewModelProvider,
        (_, _) {},
      );
      addTearDown(harvestListener.close);
      final vm = container.read(panenViewModelProvider.notifier);
      await vm.refresh();
      final result = await vm.submit(
        HarvestDraft(
          date: '2026-10-10',
          rows: [
            for (final id in ['1', '2', '3'])
              HarvestDraftRow(
                transferId: id,
                plantCount: 5,
                total: '2.50',
                reject: '0.25',
              ),
          ],
        ),
      );
      expect(result, HarvestSubmitResult.saved);
      expect(detailGets, ['1', '2']);
      final tables = container.read(connectedTableProvider).records;
      expect(tables.firstWhere((t) => t.id == '1').activePlants, 190);
      expect(tables.firstWhere((t) => t.id == '2').activePlants, 195);
    },
  );
}
