import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/connected_table_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/panen_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/laporan_panen_page.dart';
import 'package:hidrosense_mobile/views/pages/panen_form_page.dart';
import 'package:hidrosense_mobile/views/pages/panen_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:http/io_client.dart';

class _RealHttp extends HttpOverrides {}

Future<Map<String, dynamic>> _fixtureStartup(
  StreamIterator<String> stdout,
  StringBuffer errors,
) async {
  final hasLine = await stdout.moveNext().timeout(
    const Duration(seconds: 30),
    onTimeout: () =>
        throw StateError('Harvest fixture startup timed out: $errors'),
  );
  if (!hasLine) {
    throw StateError(
      'Harvest fixture stdout closed before startup JSON; stderr=$errors',
    );
  }
  try {
    return jsonDecode(stdout.current) as Map<String, dynamic>;
  } on FormatException {
    throw StateError(
      'Harvest fixture startup was not JSON: ${stdout.current}; stderr=$errors',
    );
  }
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (ready()) return;
  }
  fail(
    'HTTP widget condition timed out. Visible text:\n${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().join('\n')}',
  );
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    ScaffoldMessenger.of(tester.element(target)).removeCurrentSnackBar();
    await tester.pump();
  }
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  test(
    'fixture startup EOF fails promptly with stderr in the diagnostic',
    () async {
      final errors = StringBuffer('fixture initialization failed');
      final stdout = StreamIterator(const Stream<String>.empty());
      try {
        await expectLater(
          _fixtureStartup(
            stdout,
            errors,
          ).timeout(const Duration(milliseconds: 200)),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'diagnostic',
              'Harvest fixture stdout closed before startup JSON; stderr=fixture initialization failed',
            ),
          ),
        );
      } finally {
        await stdout.cancel();
      }
    },
  );
  testWidgets(
    'widgets persist multi-batch harvest, sorting and nullable notes through fresh HTTP sessions',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final info = (await tester.runAsync(() async {
        final server = await Process.start('node', [
          '--import',
          'tsx',
          'test-support/harvest-ui-server.js',
        ], workingDirectory: '../backend');
        final errors = StringBuffer();
        final stderr = server.stderr
            .transform(utf8.decoder)
            .listen(errors.write);
        final stdout = StreamIterator(
          server.stdout.transform(utf8.decoder).transform(const LineSplitter()),
        );
        addTearDown(() async {
          server.kill();
          try {
            await server.exitCode.timeout(const Duration(seconds: 10));
          } finally {
            await stdout.cancel();
            await stderr.cancel();
          }
        });
        return _fixtureStartup(stdout, errors);
      }))!;
      final origin = info['url'] as String;
      final inspection = IOClient(_RealHttp().createHttpClient(null));
      addTearDown(inspection.close);
      Future<Map<String, dynamic>> state() async => (await tester.runAsync(
        () async =>
            jsonDecode(
                  (await inspection.get(
                    Uri.parse('$origin/__fixture/state'),
                  )).body,
                )
                as Map<String, dynamic>,
      ))!;
      ProviderContainer? container;
      ApiClient? api;
      ProviderSubscription<TableState>? tableWatch;
      addTearDown(() {
        tableWatch?.close();
        container?.dispose();
        api?.close();
      });
      Future<void> session(Widget page) async {
        await tester.pumpWidget(const SizedBox.shrink());
        tableWatch?.close();
        container?.dispose();
        api?.close();
        api = ApiClient(
          IOClient(_RealHttp().createHttpClient(null)),
          baseUri: Uri.parse('$origin/api/v1'),
          allowInsecureLocalhost: true,
        );
        final user = (await tester.runAsync(
          () => api!.login('petani', 'Fixture password 2026!'),
        ))!;
        container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(api!),
            sessionProvider.overrideWith(
              (_) => SessionViewModel(
                api!,
                initialState: SessionState(user: user),
              ),
            ),
          ],
        );
        tableWatch = container!.listen(connectedTableProvider, (_, _) {});
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container!,
            child: MaterialApp(theme: AppTheme.lightTheme, home: page),
          ),
        );
        await _wait(
          tester,
          () => !container!.read(connectedTableProvider).loading,
        );
      }

      Finder field(String label, {bool last = false}) {
        final found = find.widgetWithText(TextField, label);
        return last ? found.last : found.first;
      }

      Future<void> enter(
        String label,
        String value, {
        bool last = false,
      }) async {
        final target = field(label, last: last);
        await _reveal(tester, target);
        await tester.enterText(target, value);
        tester.testTextInput.hide();
        await tester.pump();
      }

      Future<void> assertCounts(Map<String, dynamic> snapshot) async {
        expect((snapshot['transfers'] as List).map((t) => t['tanaman_aktif']), [
          60,
          90,
        ]);
        expect((snapshot['tables'] as List).map((t) => t['tanaman_aktif']), [
          90,
          60,
        ]);
        expect(
          (snapshot['tables'] as List).map((t) => t['kapasitas_tersedia']),
          [10, 20],
        );
        expect((snapshot['details'] as List).map((d) => d['jumlah_tanaman']), [
          10,
          20,
        ]);
        expect((snapshot['details'] as List).map((d) => d['id_pemindahan']), [
          1,
          2,
        ]);
        expect(
          (snapshot['harvests'] as List).single['tanggal_panen'],
          info['today'],
        );
      }

      final seeded = await state();
      expect((seeded['transfers'] as List).map((t) => t['hss']), [20, 20]);
      expect((seeded['transfers'] as List).map((t) => t['hst']), [5, 5]);
      expect((seeded['transfers'] as List).map((t) => t['estimasi_panen']), [
        info['estimateDate'],
        info['estimateDate'],
      ]);
      expect((seeded['transfers'] as List).map((t) => t['sisa_hari_panen']), [
        25,
        25,
      ]);
      await session(const PanenPage());
      await _wait(tester, () => find.text('Batch #1').evaluate().isNotEmpty);
      expect(
        find.textContaining('Estimasi ${info['estimateDate']}'),
        findsNWidgets(2),
      );
      await _tap(tester, find.text('Batch #1'));
      await _wait(
        tester,
        () => find.byType(PanenFormPage).evaluate().isNotEmpty,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        '1',
      );
      await enter('Jumlah', '10');
      await enter('Berat total (kg)', '2,50');
      await enter('Berat reject (kg)', '0.50');
      await _tap(tester, find.text('Tambah Batch'));
      await _tap(tester, find.byType(DropdownButtonFormField<String>).last);
      await tester.tap(find.text('#2 • Meja #2').last);
      await tester.pumpAndSettle();
      await enter('Jumlah', '20', last: true);
      await enter('Berat total (kg)', '3.00', last: true);
      await enter('Berat reject (kg)', '1,00', last: true);
      await enter('Catatan panen', 'Panen dua meja');
      await _reveal(tester, find.text('Simpan Hasil Panen'));
      await tester.tap(find.text('Simpan Hasil Panen'));
      await tester.tap(find.text('Simpan Hasil Panen'));
      await tester.pump();
      await _wait(tester, () => find.byType(PanenFormPage).evaluate().isEmpty);
      final created = await state();
      await assertCounts(created);
      expect((created['harvests'] as List).length, 1);
      expect((created['details'] as List).length, 2);
      expect(
        (created['details'] as List).fold<int>(
          0,
          (sum, d) => sum + (d['berat_minor'] as int),
        ),
        400,
      );
      expect(
        container!
            .read(connectedTableProvider)
            .records
            .map((t) => t.activePlants)
            .toList()
          ..sort(),
        [60, 90],
      );
      final writes = (created['requests'] as List)
          .where((r) => r['method'] == 'POST')
          .toList();
      expect(writes.length, 1);
      final createBody = writes.single['body'] as Map;
      expect((createBody['details'] as List).map((d) => d['berat_total']), [
        '2.50',
        '3.00',
      ]);
      expect((created['receipts'] as List).length, 1);
      final receipt =
          jsonDecode(
                (created['receipts'] as List).single['result_json'] as String,
              )
              as Map;
      expect(receipt['data']['berat_layak'], '4.00');
      final harvestId = '${(created['harvests'] as List).single['id_panen']}';
      await session(LaporanPanenPage(harvestId: harvestId));
      await _wait(
        tester,
        () => find.text('Layak jual: 4.00 kg').evaluate().isNotEmpty,
      );
      expect(find.text('30 tanaman'), findsOneWidget);
      expect(find.text('Catatan: Panen dua meja'), findsOneWidget);
      for (final forbidden in [
        'PDF',
        'Harga',
        'pcs',
        'Grade',
        'Grand Rapids',
      ]) {
        expect(find.textContaining(forbidden), findsNothing);
      }
      await _tap(tester, find.text('Koreksi Sortasi atau Catatan'));
      await _wait(
        tester,
        () => find.text('Koreksi berat sortasi').evaluate().isNotEmpty,
      );
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(
        find.widgetWithText(TextField, 'Jumlah'),
        findsNothing,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Tanggal panen: ${info['today']}',
              ),
            )
            .onPressed,
        isNull,
      );
      await _tap(tester, find.text('Koreksi berat sortasi'));
      await enter('Berat total (kg)', '3.00');
      await enter('Catatan panen', 'Sortasi diperiksa');
      await _tap(tester, find.text('Simpan Koreksi'));
      await _wait(tester, () => find.byType(PanenFormPage).evaluate().isEmpty);
      final corrected = await state();
      await assertCounts(corrected);
      expect(
        (corrected['details'] as List).fold<int>(
          0,
          (sum, d) => sum + (d['berat_minor'] as int),
        ),
        450,
      );
      expect(
        (corrected['harvests'] as List).single['keterangan'],
        'Sortasi diperiksa',
      );
      expect((corrected['details'] as List).last['berat_minor'], 200);
      expect((corrected['details'] as List).last['berat_reject_minor'], 100);
      await session(LaporanPanenPage(harvestId: harvestId));
      await _wait(
        tester,
        () => find.text('Layak jual: 4.50 kg').evaluate().isNotEmpty,
      );
      expect(find.text('Catatan: Sortasi diperiksa'), findsOneWidget);
      await _tap(tester, find.text('Koreksi Sortasi atau Catatan'));
      await _wait(
        tester,
        () => find
            .widgetWithText(TextField, 'Catatan panen')
            .evaluate()
            .isNotEmpty,
      );
      await enter('Catatan panen', '');
      await _tap(tester, find.text('Simpan Koreksi'));
      await _wait(tester, () => find.byType(PanenFormPage).evaluate().isEmpty);
      final cleared = await state();
      await assertCounts(cleared);
      expect((cleared['harvests'] as List).single['keterangan'], isNull);
      expect(
        (cleared['details'] as List).fold<int>(
          0,
          (sum, d) => sum + (d['berat_minor'] as int),
        ),
        450,
      );
      expect((cleared['receipts'] as List).length, 3);
      final mutations = (cleared['requests'] as List)
          .where((r) => ['POST', 'PATCH'].contains(r['method']))
          .toList();
      expect(mutations.length, 3);
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(mutations.map((r) => r['key']).toSet().length, 3);
      for (final mutation in mutations) {
        expect(mutation['key'], matches(uuid));
      }
      expect(mutations.last['body']['keterangan'], isNull);
      expect(mutations.last['body'].containsKey('details'), isFalse);
      await session(LaporanPanenPage(harvestId: harvestId));
      await _wait(
        tester,
        () => find.text('Layak jual: 4.50 kg').evaluate().isNotEmpty,
      );
      expect(find.text('Catatan: Tidak ada catatan.'), findsOneWidget);
      expect(
        container!
            .read(panenViewModelProvider)
            .detailReads[harvestId]!
            .record!
            .version,
        '3',
      );
      await session(const PanenFormPage(transferId: '1'));
      await _wait(
        tester,
        () => find.textContaining('90 tanaman aktif').evaluate().isNotEmpty,
      );
      expect(
        tester
            .widget<TextField>(field('Jumlah'))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(field('Berat total (kg)')).enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      tableWatch?.close();
      tableWatch = null;
      container?.dispose();
      container = null;
      api?.close();
      api = null;
      inspection.close();
      await tester.pump(const Duration(seconds: 20));
    },
  );
}
