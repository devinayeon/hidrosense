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
    );
  });
  tearDown(() {
    if (vm.mounted) vm.dispose();
    api.close();
  });

  test(
    'network retries reuse UUID; editing payload creates a new UUID',
    () async {
      repo.onCreate = (_, _) async =>
          throw const ApiException(0, 'NETWORK', 'Offline');
      await vm.refresh();
      expect(await vm.submit(draft), DamageSubmitResult.failed);
      expect(await vm.submit(draft), DamageSubmitResult.failed);
      expect(repo.keys[0], repo.keys[1]);
      expect(repo.keys.first, matches(r'^[0-9a-f-]{36}$'));
      await vm.submit(
        const DamageDraft(
          transferId: '1',
          date: '2026-09-20',
          plantCount: 6,
          category: 'Busuk akar',
        ),
      );
      expect(repo.keys[2], isNot(repo.keys[1]));
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
      expect(vm.state.refreshWarning, contains('Laporan tersimpan'));
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
    'capacity conflict reloads active count and preserves the failed command',
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
}
