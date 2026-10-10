import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hidrosense_mobile/data/models/damage_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/damage_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'support/damage_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient api;
  late FakeDamageRepository repo;
  late DamageViewModel vm;
  setUp(() {
    api = apiFor((_) async => throw StateError('Unexpected request'));
    repo = FakeDamageRepository(api);
    vm = DamageViewModel(
      repo,
      '1',
      () async {},
      canWrite: true,
      autoLoad: false,
      clock: () => DateTime.utc(2026, 10, 9),
    );
  });
  tearDown(() {
    if (vm.mounted) vm.dispose();
    api.close();
  });

  test(
    'network retries reuse UUID and block changed payload until definitive rejection',
    () async {
      repo.onCreate = (_, _) async =>
          throw const ApiException(0, 'NETWORK', 'Offline');
      await vm.refresh();
      expect(await vm.submit(draft), DamageSubmitResult.failed);
      expect(await vm.submit(draft), DamageSubmitResult.failed);
      expect(repo.keys[0], repo.keys[1]);
      expect(repo.keys.first, matches(r'^[0-9a-f-]{36}$'));
      const changed = DamageDraft(
        transferId: '1',
        date: '2026-09-20',
        plantCount: 6,
        category: 'Busuk akar',
      );
      expect(await vm.submit(changed), DamageSubmitResult.failed);
      expect(repo.keys, hasLength(2));
      repo.onCreate = (_, _) async => throw const ApiException(
        409,
        'DAMAGE_EXCEEDS_ACTIVE',
        'Jumlah melebihi sisa aktif',
      );
      expect(await vm.submit(draft), DamageSubmitResult.failed);
      expect(repo.keys[2], repo.keys[1]);
      expect(vm.payloadLocked, isFalse);
      repo.onCreate = (_, _) async => DamageRecord.fromJson(damageJson());
      expect(await vm.submit(changed), DamageSubmitResult.saved);
      expect(repo.keys[3], isNot(repo.keys[2]));
    },
  );

  test('concurrent submission creates only one report', () async {
    final pending = Completer<DamageRecord>();
    repo.onCreate = (_, _) => pending.future;
    await vm.refresh();
    final first = vm.submit(draft);
    expect(await vm.submit(draft), DamageSubmitResult.busy);
    pending.complete(DamageRecord.fromJson(damageJson()));
    expect(await first, DamageSubmitResult.saved);
    expect(repo.keys.length, 1);
  });

  test(
    'uncertain committed POST can replay after remaining capacity drops below the original count',
    () async {
      repo.onCreate = (_, _) async {
        if (repo.keys.length == 1) {
          repo.transfers = [TransferRecord.fromJson(transferJson(active: 0))];
          throw TimeoutException('Response lost after commit');
        }
        return DamageRecord.fromJson(damageJson());
      };
      await vm.refresh();
      expect(await vm.submit(draft), DamageSubmitResult.failed);
      await vm.refresh();
      expect(vm.state.transfers.single.activePlants, 0);
      expect(vm.state.uncertainDraft, isNotNull);
      expect(await vm.submit(draft), DamageSubmitResult.saved);
      expect(repo.keys[0], repo.keys[1]);
      expect(vm.state.uncertainDraft, isNull);
    },
  );

  test(
    'disposed submission does not refresh another session or publish state',
    () async {
      final pending = Completer<DamageRecord>();
      var tableRefreshes = 0;
      vm.dispose();
      vm = DamageViewModel(
        repo,
        '1',
        () async {
          tableRefreshes++;
        },
        canWrite: true,
        autoLoad: false,
      );
      repo.onCreate = (_, _) => pending.future;
      await vm.refresh();
      final result = vm.submit(draft);
      vm.dispose();
      pending.complete(DamageRecord.fromJson(damageJson()));
      expect(await result, DamageSubmitResult.saved);
      expect(tableRefreshes, 0);
    },
  );

  test(
    'successful POST with failed refresh stays saved and is never posted again',
    () async {
      repo.onCreate = (_, _) async {
        repo.loadError = const ApiException(0, 'NETWORK', 'Offline');
        return DamageRecord.fromJson(damageJson());
      };
      await vm.refresh();
      expect(await vm.submit(draft), DamageSubmitResult.savedRefreshFailed);
      expect(vm.state.refreshWarning, contains('Tersimpan'));
      expect(vm.state.reports['1']!.single.id, '1');
      repo.loadError = null;
      expect(await vm.submit(draft), DamageSubmitResult.saved);
      expect(repo.keys.length, 1);
      vm.beginDraft();
      await vm.submit(draft);
      expect(repo.keys.length, 2);
    },
  );

  test(
    'table capacity refresh failure cannot turn a saved report into a failed write',
    () async {
      vm.dispose();
      vm = DamageViewModel(
        repo,
        '1',
        () async => throw StateError('Table refresh failed'),
        canWrite: true,
        autoLoad: false,
      );
      await vm.refresh();
      expect(await vm.submit(draft), DamageSubmitResult.savedRefreshFailed);
      expect(vm.state.reports['1']!.single.id, '1');
      expect(vm.state.submitting, isFalse);
    },
  );

  test(
    'capacity conflict reloads active count and releases the rejected command',
    () async {
      repo.onCreate = (_, _) async {
        repo.transfers = [TransferRecord.fromJson(transferJson(active: 2))];
        throw const ApiException(
          409,
          'DAMAGE_EXCEEDS_ACTIVE',
          'Jumlah melebihi sisa aktif',
        );
      };
      await vm.refresh();
      expect(await vm.submit(draft), DamageSubmitResult.failed);
      expect(vm.state.transfers.single.activePlants, 2);
      expect(vm.state.error, contains('sisa aktif'));
      expect(vm.state.submitting, isFalse);
      expect(vm.payloadLocked, isFalse);
    },
  );

  test(
    'validation prevents missing batch, invalid dates, and excess capacity before POST',
    () async {
      await vm.refresh();
      for (final invalid in [
        const DamageDraft(
          transferId: '2',
          date: '2026-09-20',
          plantCount: 5,
          category: 'A',
        ),
        const DamageDraft(
          transferId: '1',
          date: '2026-09-15',
          plantCount: 5,
          category: 'A',
        ),
        const DamageDraft(
          transferId: '1',
          date: '2099-01-01',
          plantCount: 5,
          category: 'A',
        ),
        const DamageDraft(
          transferId: '1',
          date: '2026-02-30',
          plantCount: 5,
          category: 'A',
        ),
        const DamageDraft(
          transferId: '1',
          date: '2026-09-20',
          plantCount: 201,
          category: 'A',
        ),
        const DamageDraft(
          transferId: '1',
          date: '2026-09-20',
          plantCount: 0,
          category: 'A',
        ),
      ]) {
        expect(await vm.submit(invalid), DamageSubmitResult.failed);
      }
      expect(repo.keys, isEmpty);
      expect(
        apiDate(jakartaToday(DateTime.utc(2026, 10, 8, 18))),
        '2026-10-09',
      );
    },
  );

  test('read-only permissions prevent writes', () async {
    vm.dispose();
    vm = DamageViewModel(
      repo,
      '1',
      () async {},
      canWrite: false,
      autoLoad: false,
    );
    await vm.refresh();
    expect(await vm.submit(draft), DamageSubmitResult.failed);
    expect(repo.keys, isEmpty);
  });

  test('disposed ViewModel ignores pending responses', () async {
    final pending = Completer<List<TransferRecord>>();
    repo.onList = () => pending.future;
    final loading = vm.refresh();
    vm.dispose();
    pending.complete([TransferRecord.fromJson(transferJson())]);
    await loading;
  });

  test(
    'changing session disposes pending state and creates an empty ViewModel',
    () async {
      final session = StateProvider<SessionUser?>((_) => farmer);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith(
            (ref) => SessionViewModel(
              api,
              initialState: SessionState(user: ref.watch(session)),
            ),
          ),
          damageRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(damageProvider('1'), (_, _) {});
      addTearDown(subscription.close);
      final old = container.read(damageProvider('1').notifier);
      await old.refresh();
      expect(old.state.transfers, isNotEmpty);
      repo.onList = () => Completer<List<TransferRecord>>().future;
      container.read(session.notifier).state = employee;
      await container.pump();
      expect(old.mounted, isFalse);
      expect(container.read(damageProvider('1')).transfers, isEmpty);
    },
  );

  test('updateTransfer updates transfer note in state', () async {
    await vm.refresh();
    final ok = await vm.updateTransfer('1', note: 'Catatan batch baru');
    expect(ok, DamageSubmitResult.saved);
    expect(vm.state.transfers.first.note, 'Catatan batch baru');
    expect(vm.state.submitting, isFalse);
    expect(
      await vm.updateTransfer('1', note: 'Catatan berikutnya'),
      DamageSubmitResult.saved,
    );
    expect(vm.state.transfers.first.note, 'Catatan berikutnya');
    expect(vm.state.submitting, isFalse);
    expect(repo.editKeys, hasLength(2));
    expect(repo.editKeys[0], isNot(repo.editKeys[1]));
  });

  test('updateDamage updates damage record and reloads state', () async {
    repo.reports = [DamageRecord.fromJson(damageJson(id: '1'))];
    await vm.refresh();
    final ok = await vm.updateDamage(
      '1',
      plantCount: 12,
      category: 'Batang Patah',
      note: 'Angin kencang',
    );
    expect(ok, DamageSubmitResult.saved);
    expect(vm.state.reports['1']!.single.plantCount, 12);
    expect(vm.state.reports['1']!.single.category, 'Batang Patah');
    expect(vm.state.reports['1']!.single.note, 'Angin kencang');
    expect(vm.state.submitting, isFalse);
    expect(
      await vm.updateDamage('1', plantCount: 13),
      DamageSubmitResult.saved,
    );
    expect(vm.state.reports['1']!.single.plantCount, 13);
    expect(vm.state.submitting, isFalse);
    expect(repo.editKeys, hasLength(2));
    expect(repo.editKeys[0], isNot(repo.editKeys[1]));
  });

  test('concurrent updates return busy and send one PATCH', () async {
    final pending = Completer<TransferRecord>();
    repo.onUpdateTransfer = (_, _) => pending.future;
    await vm.refresh();
    final first = vm.updateTransfer('1', note: 'Baru');
    expect(vm.state.submitting, isTrue);
    expect(await vm.updateTransfer('1', note: 'Lain'), DamageSubmitResult.busy);
    expect(await vm.updateDamage('1', plantCount: 6), DamageSubmitResult.busy);
    expect(repo.editKeys, hasLength(1));
    pending.complete(
      TransferRecord.fromJson({...transferJson(), 'keterangan': 'Baru'}),
    );
    expect(await first, DamageSubmitResult.saved);
    expect(vm.state.submitting, isFalse);
  });

  for (final target in ['batch', 'damage']) {
    test('$target PATCH keeps receipt when refresh fails', () async {
      repo.reports = [DamageRecord.fromJson(damageJson())];
      repo.onUpdateTransfer = (_, note) async {
        repo.loadError = const ApiException(0, 'NETWORK', 'Offline');
        return TransferRecord.fromJson({...transferJson(), 'keterangan': note});
      };
      repo.onUpdateDamage = (id, {date, plantCount, category, note}) async {
        repo.loadError = const ApiException(0, 'NETWORK', 'Offline');
        return DamageRecord.fromJson({
          ...damageJson(id: id),
          'version': '2',
          'keterangan': note,
        });
      };
      await vm.refresh();
      final result = target == 'batch'
          ? await vm.updateTransfer('1', note: 'Tersimpan')
          : await vm.updateDamage('1', note: 'Tersimpan');
      expect(result, DamageSubmitResult.savedRefreshFailed);
      expect(vm.state.refreshWarning, contains('Tersimpan'));
      expect(vm.state.error, isNull);
      expect(vm.state.submitting, isFalse);
      expect(
        target == 'batch'
            ? vm.state.transfers.single.note
            : vm.state.reports['1']!.single.note,
        'Tersimpan',
      );
      repo.loadError = null;
      expect(
        target == 'batch'
            ? await vm.updateTransfer('1', note: 'Tersimpan')
            : await vm.updateDamage('1', note: 'Tersimpan'),
        DamageSubmitResult.saved,
      );
      expect(repo.editKeys, hasLength(1));
    });

    test(
      'uncertain $target PATCH replays after disposal for same account',
      () async {
        final commands = <(String, String, String), DamageCommand>{};
        vm.dispose();
        vm = DamageViewModel(
          repo,
          '1',
          () async {},
          canWrite: true,
          autoLoad: false,
          userId: farmer.id,
          commands: commands,
        );
        repo.reports = [DamageRecord.fromJson(damageJson())];
        repo.onUpdateTransfer = (_, note) async {
          if (repo.editKeys.length == 1) {
            throw TimeoutException('Response lost');
          }
          return TransferRecord.fromJson({
            ...transferJson(),
            'keterangan': note,
          });
        };
        repo.onUpdateDamage = (id, {date, plantCount, category, note}) async {
          if (repo.editKeys.length == 1) {
            throw TimeoutException('Response lost');
          }
          return DamageRecord.fromJson({
            ...damageJson(id: id),
            'keterangan': note,
          });
        };
        await vm.refresh();
        expect(
          target == 'batch'
              ? await vm.updateTransfer('1', note: 'Sama')
              : await vm.updateDamage('1', note: 'Sama'),
          DamageSubmitResult.failed,
        );
        expect(vm.payloadLocked, isTrue);
        final key = repo.editKeys.single;
        vm.dispose();
        vm = DamageViewModel(
          repo,
          '1',
          () async {},
          canWrite: true,
          autoLoad: false,
          userId: farmer.id,
          commands: commands,
        );
        await vm.refresh();
        expect(vm.payloadLocked, isTrue);
        expect(vm.pendingTarget, '$target:1');
        expect(
          target == 'batch'
              ? await vm.updateTransfer('1', note: 'Berubah')
              : await vm.updateDamage('1', note: 'Berubah'),
          DamageSubmitResult.failed,
        );
        expect(repo.editKeys, hasLength(1));
        expect(
          target == 'batch'
              ? await vm.updateTransfer('1', note: 'Sama')
              : await vm.updateDamage('1', note: 'Sama'),
          DamageSubmitResult.saved,
        );
        expect(repo.editKeys, [key, key]);
        expect(vm.payloadLocked, isFalse);
        expect(vm.state.submitting, isFalse);
      },
    );
  }

  test(
    'another account receives a new PATCH key and no pending payload',
    () async {
      final commands = <(String, String, String), DamageCommand>{};
      vm.dispose();
      vm = DamageViewModel(
        repo,
        '1',
        () async {},
        canWrite: true,
        autoLoad: false,
        userId: farmer.id,
        commands: commands,
      );
      repo.onUpdateTransfer = (_, _) async =>
          throw TimeoutException('Response lost');
      await vm.refresh();
      expect(
        await vm.updateTransfer('1', note: 'Sama'),
        DamageSubmitResult.failed,
      );
      final firstKey = repo.editKeys.single;
      vm.dispose();
      vm = DamageViewModel(
        repo,
        '1',
        () async {},
        canWrite: true,
        autoLoad: false,
        userId: employee.id,
        commands: commands,
      );
      await vm.refresh();
      expect(vm.payloadLocked, isFalse);
      expect(vm.pendingTarget, isNull);
      expect(vm.state.uncertainDraft, isNull);
      repo.onUpdateTransfer = null;
      expect(
        await vm.updateTransfer('1', note: 'Sama'),
        DamageSubmitResult.saved,
      );
      expect(repo.editKeys, hasLength(2));
      expect(repo.editKeys.last, isNot(firstKey));
    },
  );

  test('read-only user cannot updateTransfer or updateDamage', () async {
    final readOnlyVm = DamageViewModel(
      repo,
      '1',
      () async {},
      canWrite: false,
      autoLoad: false,
    );
    addTearDown(readOnlyVm.dispose);
    await readOnlyVm.refresh();
    expect(
      await readOnlyVm.updateTransfer('1', note: 'test'),
      DamageSubmitResult.failed,
    );
    expect(
      await readOnlyVm.updateDamage('1', plantCount: 5),
      DamageSubmitResult.failed,
    );
    expect(readOnlyVm.state.error, contains('tidak diizinkan'));
  });
}
