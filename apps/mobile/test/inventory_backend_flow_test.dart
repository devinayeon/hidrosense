import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/inventory_draft.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TracingClient extends http.BaseClient {
  _TracingClient(this.inner);
  final http.Client inner;
  final List<String> trace = [];
  bool loseStockReceipt = true;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    trace.add('${request.method} ${request.url.path}');
    final response = await inner.send(request);
    if (loseStockReceipt &&
        request.method == 'POST' &&
        request.url.path.endsWith('/stok') &&
        response.statusCode == 201) {
      loseStockReceipt = false;
      await response.stream.drain<void>();
      throw http.ClientException('Response lost after stock commit');
    }
    return response;
  }

  @override
  void close() => inner.close();
}

void main() {
  test(
    'real Fastify persistence: 101-item save, lost stock receipt replay, edit and archive without saldo fanout',
    () async {
      final server = await Process.start('node', [
        '--input-type=module',
        '--import',
        'tsx',
        '-e',
        r'''
import { fixture } from './test-support/fixture.js';
const cleanups=[];
const f=await fixture({after:fn=>cleanups.push(fn)});
await f.db.execute("INSERT INTO jenis_inventaris(nama_jenis) VALUES('Benih')");
for(let i=0;i<100;i++) await f.db.execute({sql:'INSERT INTO inventaris(id_jenis_inventaris,nama_barang,satuan) VALUES(1,?,?)',args:[`Fixture ${i}`,'Pcs']});
console.log(JSON.stringify({url:await f.app.listen({host:'127.0.0.1',port:0})}));
process.on('SIGTERM',async()=>{for(const cleanup of cleanups.reverse())await cleanup();process.exit(0);});
''',
      ], workingDirectory: '../backend');
      final errors = <String>[];
      final stderr = server.stderr.transform(utf8.decoder).listen(errors.add);
      addTearDown(() async {
        server.kill();
        await server.exitCode.timeout(const Duration(seconds: 10));
        await stderr.cancel();
      });
      final line = await server.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw StateError(errors.join()),
          );
      final url = (jsonDecode(line) as Map)['url'];
      final client = _TracingClient(IOClient(HttpClient()));
      final api = ApiClient(
        client,
        baseUri: Uri.parse('$url/api/v1'),
        allowInsecureLocalhost: true,
      );
      addTearDown(api.close);
      await api.login('petani', 'Fixture password 2026!');
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: InventoryCache.createSchema,
        ),
      );
      final cache = InventoryCache(db);
      addTearDown(cache.close);
      final repo = InventoryRepository(api, Future.value(cache), userId: '1');
      final vm = ConnectedInventoryViewModel(repo, autoLoad: false);
      addTearDown(vm.dispose);
      const input = InventoryDraft(
        name: 'Persisted seed',
        categoryId: '1',
        unit: 'Pcs',
        minimum: '5',
        initialStock: '10',
      );
      client.trace.clear();
      await expectLater(
        vm.saveItem(input),
        throwsA(isA<http.ClientException>()),
      );
      expect(vm.state.pendingDraft, same(input));
      expect(await vm.saveItem(input), null);
      expect(
        client.trace.length,
        9,
      ); // Create + two stock attempts + six pages.
      expect(
        client.trace.where((r) => r == 'POST /api/v1/inventaris').length,
        1,
      );
      expect(client.trace.where((r) => r.endsWith('/saldo')), isEmpty);
      expect(vm.state.records.length, 101);
      final item = vm.state.records.singleWhere(
        (r) => r.name == 'Persisted seed',
      );
      expect(item.id, '101');
      expect(item.balance, '10');
      expect(item.isLow, false);
      expect((await repo.cached())!.records.last.balance, '10');
      final history = await repo.fetchStockHistory(inventoryId: item.id);
      expect(history.length, 1);
      expect(history.single.details.single.amount, '10');
      client.trace.clear();
      await vm.saveItem(
        InventoryDraft(
          id: item.id,
          name: 'Updated seed',
          categoryId: '1',
          unit: 'Pcs',
          minimum: '20',
          initialStock: '',
        ),
      );
      expect(client.trace.length, 7); // PATCH + six pages.
      expect(vm.state.records.last.balance, '10');
      expect(vm.state.records.last.isLow, true);
      client.trace.clear();
      await vm.deactivateItem(item.id);
      expect(client.trace.length, 6); // Archive + five pages.
      expect(vm.state.records.length, 100);
      expect((await repo.cached())!.records.length, 100);
      final archived = await api.get('inventaris/${item.id}');
      expect(archived['data']['status_aktif'], 0);
      expect(archived['data']['saldo'], '10');
    },
  );
}
