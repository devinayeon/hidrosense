// Regresi BUG-07: kegagalan melepas baris setelah server menerima tidak boleh
// mengubah nasib kiriman (baris tidak boleh ditandai gagal).
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/sync_queue_item.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/v2_sync_queue.dart';
import 'package:hidrosense_mobile/viewmodels/v2_sync_replayer.dart';

/// Antrean palsu: baris dipegang di memori, `remove` sengaja selalu melempar
/// untuk meniru galat I/O SQLite sesaat.
class _FakeQueue extends V2SyncQueue {
  _FakeQueue({required List<SyncQueueItem> items, this.throwOnRemove = true})
    : _rows = [...items],
      super(openStore: () async => null, serverOrigin: 'test', userId: 'u1');

  final List<SyncQueueItem> _rows;
  final bool throwOnRemove;
  int removeCalls = 0;
  int markFailedCalls = 0;
  int markConflictCalls = 0;

  @override
  List<SyncQueueItem> get items => List.unmodifiable(_rows);

  @override
  Future<void> remove(String key) async {
    removeCalls++;
    if (throwOnRemove) throw Exception('penyimpanan sibuk');
  }

  @override
  Future<void> markFailed(String key, String error) async {
    markFailedCalls++;
  }

  @override
  Future<void> markConflict(String key, String error) async {
    markConflictCalls++;
  }
}

class _SemaianSender implements V2SyncSender {
  _SemaianSender({this.error});

  /// Bila diisi, `send` melempar galat ini alih-alih berhasil.
  final Object? error;

  @override
  SyncQueueJenis get jenis => SyncQueueJenis.semaian;

  @override
  Future<void> send(SyncQueueItem item) async {
    if (error != null) throw error!;
  }
}

SyncQueueItem _item({String key = 'k1', SyncQueueJenis jenis = SyncQueueJenis.semaian}) {
  return SyncQueueItem(
    key: key,
    jenis: jenis,
    subtitle: 'sub',
    target: 'create',
    payload: '{}',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  test('kegagalan melepas baris tidak menandai baris gagal (BUG-07)', () async {
    final queue = _FakeQueue(items: [_item()]);
    final replayer = V2SyncReplayer(queue: queue, senders: [_SemaianSender()]);

    final run = await replayer.run();

    // Server sudah menerima: baris dihitung terkirim walau pembersihan gagal.
    expect(run.sent, 1);
    expect(run.failed, 0);
    expect(run.pending, 0);
    expect(queue.markFailedCalls, 0);
    expect(queue.markConflictCalls, 0);
    expect(queue.removeCalls, 1);
  });

  test('penolakan pasti dari server tetap menandai baris gagal', () async {
    final queue = _FakeQueue(items: [_item()]);
    final replayer = V2SyncReplayer(
      queue: queue,
      senders: [
        _SemaianSender(
          error: const ApiException(400, 'VALIDATION_ERROR', 'tolak'),
        ),
      ],
    );

    final run = await replayer.run();

    expect(run.sent, 0);
    expect(run.failed, 1);
    expect(queue.markFailedCalls, 1);
    expect(queue.removeCalls, 0);
  });

  test('antrean tetap dibersihkan saat pengiriman berhasil', () async {
    final queue = _FakeQueue(items: [_item()], throwOnRemove: false);
    final replayer = V2SyncReplayer(queue: queue, senders: [_SemaianSender()]);

    final run = await replayer.run();

    expect(run.sent, 1);
    expect(queue.removeCalls, 1);
    expect(queue.markFailedCalls, 0);
  });
}
