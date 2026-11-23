// Regresi: baris konflik panen (409 HARVEST_VERSION_CONFLICT saat kirim ulang)
// harus bisa diselesaikan lewat dialog 11.8 ("Pakai data server" / "Kirim ulang
// punya saya"). Sebelum perbaikan tidak ada resolver untuk jenis panen, jadi
// ketukan pada baris konflik selalu berakhir "Konflik belum selesai".
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hidrosense_mobile/data/models/harvest_record.dart';
import 'package:hidrosense_mobile/data/models/sync_queue_item.dart';
import 'package:hidrosense_mobile/viewmodels/panen_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/v2_panen_sender.dart';
import 'package:hidrosense_mobile/viewmodels/v2_penjualan_store.dart';
import 'package:hidrosense_mobile/viewmodels/v2_sync_queue.dart';
import 'package:hidrosense_mobile/viewmodels/v2_sync_replayer.dart';
import 'support/harvest_fixture.dart';

/// Antrean di memori: cukup mencatat pemanggilan `remove`.
class _Queue extends V2SyncQueue {
  _Queue()
    : super(openStore: () async => null, serverOrigin: 'test', userId: 'u1');

  int removeCalls = 0;

  void seed(List<SyncQueueItem> items) => state = List.unmodifiable(items);

  @override
  Future<void> remove(String key) async {
    removeCalls++;
  }
}

SyncQueueItem _konflikPanen({String target = '1', String version = '3'}) =>
    SyncQueueItem(
      key: 'k-panen-1',
      jenis: SyncQueueJenis.panen,
      subtitle: 'Koreksi panen',
      mode: SyncQueueMode.header,
      target: target,
      payload: '{"expected_version":"$version","keterangan":"koreksi HP"}',
      expectedVersion: version,
      status: SyncQueueStatus.konflik,
      error: 'Data sudah berubah. Muat ulang lalu coba lagi.',
      createdAt: DateTime.utc(2026, 1, 1),
    );

Future<FakeHarvestRepository> _repo() async {
  final repo = await loadedRepo();
  repo.records = [
    HarvestRecord.fromJson(
      harvestJson(id: '1', version: '7', note: 'koreksi HP'),
    ),
  ];
  return repo;
}

void main() {
  test('pakai data server membuang isi HP tanpa menyentuh server', () async {
    final repo = await _repo();
    final queue = _Queue();
    final sender = V2PanenSender(repo, queue);

    await sender.resolveConflict(_konflikPanen(), useServer: true);

    expect(queue.removeCalls, 1);
    expect(repo.targets, isEmpty);
  });

  test('kirim ulang punya saya memakai versi server terbaru sebagai tiket', () async {
    final repo = await _repo();
    final queue = _Queue();
    final sender = V2PanenSender(repo, queue);

    await sender.resolveConflict(_konflikPanen(), useServer: false);

    expect(repo.bodies.single['expected_version'], '7');
    expect(repo.bodies.single['keterangan'], 'koreksi HP');
    expect(queue.removeCalls, 1);
  });

  test('resolver panen terpasang di replayer produksi', () async {
    final repo = await _repo();
    final queue = _Queue()..seed([_konflikPanen()]);
    final container = ProviderContainer(
      overrides: [
        harvestRepositoryProvider.overrideWithValue(repo),
        v2SyncQueueProvider.overrideWith((ref) => queue),
      ],
    );
    addTearDown(container.dispose);

    final replayer = V2SyncReplayer(
      queue: queue,
      senders: [container.read(v2PanenSenderProvider)],
      resolvers: container.read(v2SyncResolversProvider),
    );
    // Sebelum perbaikan daftar resolver kosong -> "belum bisa diselesaikan".
    await replayer.resolveConflict('k-panen-1', useServer: false);

    expect(repo.bodies.single['expected_version'], '7');
    expect(queue.removeCalls, 1);
  });
}
