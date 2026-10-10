import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/business_date.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/catat_kerusakan_page.dart';
import 'package:hidrosense_mobile/views/pages/form_meja_nft_page.dart';
import 'package:hidrosense_mobile/views/pages/info_meja_page.dart';
import 'package:hidrosense_mobile/views/pages/meja_nft_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/custom_back_button.dart';
import 'package:hidrosense_mobile/views/widgets/seedling_transfer_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class _RealHttpOverrides extends HttpOverrides {}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.inner);
  final http.Client inner;
  final writes =
      <
        ({
          String path,
          String? key,
          int status,
          dynamic data,
          dynamic operation,
        })
      >[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    final bytes = await response.stream.toBytes();
    if (['POST', 'PATCH'].contains(request.method) &&
        !request.url.path.contains('/auth/')) {
      final body = jsonDecode(utf8.decode(bytes)) as Map;
      writes.add((
        path: request.url.path,
        key: request.headers['Idempotency-Key'],
        status: response.statusCode,
        data: body['data'],
        operation: body['operation'],
      ));
    }
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() => inner.close();
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 150; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (ready()) return;
  }
  expect(
    ready(),
    isTrue,
    reason: tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .join('\n'),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(milliseconds: 400));
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    ScaffoldMessenger.of(tester.element(finder)).removeCurrentSnackBar();
    await tester.pump();
  }
  if (tester.widget(finder) is IconButton) {
    await _wait(
      tester,
      () => tester.widget<IconButton>(finder).onPressed != null,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'real backend persists all table, batch and damage correction flows',
    (tester) async {
      late _RecordingClient transport;
      final api = (await tester.runAsync(() async {
        final server = await Process.start('node', [
          '--input-type=module',
          '--import',
          'tsx',
          '-e',
          r'''
import { fixture } from './test-support/fixture.js';
const cleanups = [];
const f = await fixture({after: (fn) => cleanups.push(fn)});
f.advance(Date.now() - f.clock());
await f.db.execute("INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih,status_penyemaian) VALUES(1,'2026-09-01',600,'aktif')");
f.app.get('/api/v1/qa/receipts', async () => ({data: (await f.db.execute('SELECT operation_key,result_json FROM sync_operations ORDER BY id_change')).rows}));
const url = await f.app.listen({host:'127.0.0.1',port:0});
console.log(JSON.stringify({url}));
process.on('SIGTERM', async () => { for (const cleanup of cleanups.reverse()) await cleanup(); process.exit(0); });
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
        transport = _RecordingClient(
          IOClient(_RealHttpOverrides().createHttpClient(null)),
        );
        return ApiClient(
          transport,
          baseUri: Uri.parse('$url/api/v1'),
          allowInsecureLocalhost: true,
        );
      }))!;
      addTearDown(api.close);
      final user = await tester.runAsync(
        () => api.login('petani', 'Fixture password 2026!'),
      );
      final inspector = (await tester.runAsync(() async {
        final client = ApiClient(
          IOClient(_RealHttpOverrides().createHttpClient(null)),
          baseUri: api.baseUri,
          allowInsecureLocalhost: true,
        );
        await client.login('petani', 'Fixture password 2026!');
        return client;
      }))!;
      addTearDown(inspector.close);
      Future<Map<String, dynamic>> data(String path) async =>
          (await tester.runAsync(() => inspector.get(path)))!['data']
              as Map<String, dynamic>;
      Future<void> back() => _tap(tester, find.byType(CustomBackButton).last);
      Future<void> batches() =>
          _tap(tester, find.text('Batch & Laporan Kerusakan'));
      Future<void> tableEdit({
        String? code,
        String? capacity,
        String? note,
      }) async {
        await _tap(tester, find.text('Edit Pengaturan Meja').last);
        final fields = find.descendant(
          of: find.byType(FormMejaNftPage),
          matching: find.byType(TextField),
        );
        if (code != null) await tester.enterText(fields.at(0), code);
        if (capacity != null) await tester.enterText(fields.at(1), capacity);
        if (note != null) await tester.enterText(fields.at(2), note);
        await _tap(tester, find.text('Perbarui Pengaturan Meja'));
        await _wait(
          tester,
          () => find.byType(FormMejaNftPage).evaluate().isEmpty,
        );
      }

      Future<void> transfer(int count) async {
        final sowing = SowingRecord.fromJson(await data('penyemaian/1'));
        expect(sowing.remainingSeedCount, count == 250 ? 600 : 350);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(InfoMejaPage));
        unawaited(
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SeedlingTransferSheet(
              sowingRecord: sowing,
              onTransferred: () {},
            ),
          ),
        );
        await _wait(
          tester,
          () => find
              .byType(DropdownButtonFormField<String>)
              .evaluate()
              .isNotEmpty,
        );
        await _tap(tester, find.byType(DropdownButtonFormField<String>));
        await _tap(tester, find.textContaining('Meja M-QA-2 (').last);
        await tester.enterText(find.byType(TextFormField).first, '$count');
        await tester.enterText(
          find.byType(TextFormField).last,
          count == 250 ? 'Batch awal' : 'Isi ulang',
        );
        expect(
          find.text('Tanggal pemindahan: ${apiDate(jakartaToday())}'),
          findsOneWidget,
        );
        await _wait(
          tester,
          () =>
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Simpan pemindahan'),
                  )
                  .onPressed !=
              null,
        );
        await _tap(tester, find.text('Simpan pemindahan'));
        await _wait(
          tester,
          () =>
              find.text('Pemindahan berhasil disimpan.').evaluate().isNotEmpty,
        );
        await _wait(
          tester,
          () =>
              tester
                  .widget<TextButton>(
                    find.widgetWithText(TextButton, 'Selesai'),
                  )
                  .onPressed !=
              null,
        );
        await _tap(tester, find.text('Selesai'));
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            sessionProvider.overrideWith(
              (_) =>
                  SessionViewModel(api, initialState: SessionState(user: user)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MejaNftPage(),
          ),
        ),
      );
      await _wait(
        tester,
        () =>
            find.text('Belum ada meja tanam terdaftar.').evaluate().isNotEmpty,
      );
      await _tap(tester, find.text('+ Tambah Meja NFT Baru'));
      final tableFields = find.descendant(
        of: find.byType(FormMejaNftPage),
        matching: find.byType(TextField),
      );
      await tester.enterText(tableFields.at(0), 'M-QA');
      await tester.enterText(tableFields.at(1), '250');
      await tester.enterText(tableFields.at(2), 'Catatan meja awal');
      await _tap(tester, find.text('Simpan Meja'));
      await _wait(tester, () => find.text('Meja M-QA').evaluate().isNotEmpty);
      final created = await data('meja-tanam/1');
      expect(created['jumlah_lubang'], 250);
      expect(created['keterangan'], 'Catatan meja awal');
      expect(created['version'], '1');
      await _tap(tester, find.text('Meja M-QA'));
      await tableEdit(code: 'M-QA-2', note: '');
      final edited = await data('meja-tanam/1');
      expect(edited['kode_meja'], 'M-QA-2');
      expect(edited['keterangan'], isNull);
      expect(edited['jumlah_lubang'], 250);
      expect(edited['public_id'], created['public_id']);
      expect(int.parse(edited['version'] as String), greaterThan(1));
      await transfer(250);
      final initialBatch = await data('pemindahan/1');
      final today = jakartaToday();
      final hss = today.difference(DateTime(2026, 9, 1)).inDays;
      expect(initialBatch['tanggal_pemindahan'], apiDate(today));
      expect(initialBatch['hss'], hss);
      expect(initialBatch['hst'], 0);
      await batches();
      await _wait(
        tester,
        () => find.text('HSS: $hss Hari').evaluate().isNotEmpty,
      );
      expect(find.text('HST: 0 Hari'), findsOneWidget);
      await _tap(
        tester,
        find.widgetWithIcon(IconButton, Icons.edit_note_rounded),
      );
      await tester.enterText(find.byType(TextField), 'Catatan batch tetap');
      await _tap(tester, find.widgetWithText(FilledButton, 'Simpan'));
      await _wait(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
      expect((await data('pemindahan/1'))['keterangan'], 'Catatan batch tetap');
      await _tap(tester, find.text('Catat Kerusakan'));
      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.enterText(
        find.byType(TextFormField).last,
        'Laporan persistensi',
      );
      await _tap(tester, find.text('Simpan Laporan Kerusakan'));
      await _wait(
        tester,
        () => find
            .text('Laporan kerusakan berhasil disimpan.')
            .evaluate()
            .isNotEmpty,
      );
      final report = await data('kerusakan/1');
      expect(report['jumlah_tanaman'], 5);
      expect(report['version'], '1');
      expect((await data('meja-tanam/1'))['kapasitas_tersedia'], 5);
      await _wait(
        tester,
        () => find.byType(CatatKerusakanPage).evaluate().isEmpty,
      );
      await back();
      await transfer(5);
      expect((await data('meja-tanam/1'))['tanaman_aktif'], 250);
      await batches();
      await _wait(
        tester,
        () => find.byTooltip('Ubah Laporan').evaluate().isNotEmpty,
      );
      await _tap(tester, find.widgetWithIcon(IconButton, Icons.edit_outlined));
      await tester.enterText(find.byType(TextFormField).first, '3');
      await _tap(tester, find.text('Simpan Perubahan Laporan'));
      await _wait(
        tester,
        () => find
            .textContaining('Koreksi kerusakan melebihi kapasitas')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.byType(CatatKerusakanPage), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '3',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Simpan Perubahan Laporan'),
            )
            .onPressed,
        isNotNull,
      );
      expect((await data('kerusakan/1'))['jumlah_tanaman'], 5);
      expect((await data('kerusakan/1'))['version'], report['version']);
      expect(transport.writes.last.status, 409);
      final rejectedKey = transport.writes.last.key;
      await back();
      await back();
      await tableEdit(capacity: '252');
      await batches();
      await _wait(
        tester,
        () => find.byTooltip('Ubah Laporan').evaluate().isNotEmpty,
      );
      await _tap(tester, find.widgetWithIcon(IconButton, Icons.edit_outlined));
      await tester.enterText(find.byType(TextFormField).first, '3');
      await _tap(tester, find.text('Simpan Perubahan Laporan'));
      await _wait(
        tester,
        () => find
            .text('Laporan kerusakan berhasil diperbarui.')
            .evaluate()
            .isNotEmpty,
      );
      final corrected = await data('kerusakan/1');
      await _wait(
        tester,
        () => find.byType(CatatKerusakanPage).evaluate().isEmpty,
      );
      expect(corrected['jumlah_tanaman'], 3);
      expect(corrected['public_id'], report['public_id']);
      expect(int.parse(corrected['version'] as String), greaterThan(1));
      expect(transport.writes.last.key, isNot(rejectedKey));
      await _tap(tester, find.widgetWithIcon(IconButton, Icons.edit_outlined));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '3',
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isTrue,
      );
      await back();
      await back();
      expect(find.text('252 / 252 Lubang (100%)'), findsOneWidget);
      await back();
      await _tap(tester, find.text('Meja M-QA-2'));
      expect(find.text('252 / 252 Lubang (100%)'), findsOneWidget);
      await batches();
      await _wait(
        tester,
        () => find.textContaining('3 tanaman').evaluate().isNotEmpty,
      );
      expect(find.text('Catatan: Catatan batch tetap'), findsOneWidget);
      final finalTable = await data('meja-tanam/1');
      expect(finalTable['jumlah_lubang'], 252);
      expect(finalTable['tanaman_aktif'], 252);
      expect(finalTable['kapasitas_tersedia'], 0);
      expect((await data('pemindahan/1'))['keterangan'], 'Catatan batch tetap');
      final savedWrites = transport.writes
          .where((w) => w.status >= 200 && w.status < 300)
          .toList();
      expect(savedWrites, hasLength(8));
      final receipts =
          (await tester.runAsync(() => inspector.get('qa/receipts')))!['data']
              as List;
      expect(receipts, hasLength(8));
      expect(
        receipts.map((r) => (r as Map)['operation_key']).toSet(),
        savedWrites.map((w) => w.key).toSet(),
      );
      for (final write in savedWrites) {
        expect(
          write.key,
          matches(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        );
        expect((write.data as Map)['public_id'], matches(r'^[0-9a-f-]{36}$'));
        expect(int.parse(write.data['version'] as String), greaterThan(0));
        expect(write.operation['operation_key'], write.key);
        expect(write.operation['public_id'], write.data['public_id']);
        expect(write.operation['version'], write.data['version']);
        final receipt =
            receipts.singleWhere(
                  (r) => (r as Map)['operation_key'] == write.key,
                )
                as Map;
        final stored = jsonDecode(receipt['result_json'] as String) as Map;
        expect(stored['data'], write.data);
        expect(stored['operation'], write.operation);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      inspector.close();
      api.close();
      await tester.pump();
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
