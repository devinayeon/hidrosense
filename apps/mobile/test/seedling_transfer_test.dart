import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/data/repositories/nursery_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/models/seeding_batch_model.dart';
import 'package:hidrosense_mobile/viewmodels/connected_nursery_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/info_seeding_page.dart';
import 'package:hidrosense_mobile/views/widgets/seedling_transfer_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';

const readySowing = SowingRecord(
  id: 'sem-01',
  userId: 'usr-01',
  sowingDate: '2026-09-01',
  seedCount: 100,
  status: 'aktif',
  ageDays: 20,
  isReadyToMove: true,
);

Map<String, dynamic> tableJson({
  String id = 'meja-01',
  int capacity = 12,
  String status = 'tersedia',
}) => {
  'id_meja': id,
  'kode_meja': id,
  'jumlah_lubang': 100,
  'status_meja': status,
  'kapasitas_tersedia': capacity,
};

http.Response response(Object data, {int status = 200}) =>
    http.Response(jsonEncode(data), status);

ApiClient apiFor(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      MockClient(handler),
      baseUri: Uri.parse('https://example.test/api/v1'),
    )..setTokens(accessToken: 'access', refreshToken: 'refresh');

Future<void> pumpTransfer(
  WidgetTester tester,
  ApiClient api, {
  VoidCallback? onTransferred,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        connectedNurseryProvider.overrideWith(
          (ref) => ConnectedNurseryViewModel(
            NurseryRepository(api),
            autoLoad: false,
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SeedlingTransferSheet(
            sowingRecord: readySowing,
            onTransferred: onTransferred ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> chooseTable(WidgetTester tester, String id) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Meja $id').last);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Simpan pemindahan'));
  await tester.tap(find.text('Simpan pemindahan'));
  await tester.pump();
}

void main() {
  test(
    'transfer sends exactly the backend contract, including optional note',
    () async {
      var calls = 0;
      final api = apiFor((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/pemindahan');
        expect(request.headers['Authorization'], 'Bearer access');
        expect(jsonDecode(request.body), {
          'id_penyemaian': 'sem-01',
          'id_meja': 'meja-01',
          'tanggal_pemindahan': '2026-10-07',
          'jumlah_tanaman': 12,
          if (calls == 0) 'keterangan': 'Rak A',
        });
        calls++;
        return response({
          'success': true,
          'data': {'id_pemindahan': 'move-01'},
        }, status: 201);
      });
      final repo = NurseryRepository(api);
      for (final note in ['Rak A', '']) {
        await repo.transferSowing(
          sowingId: 'sem-01',
          tableId: 'meja-01',
          transferDate: '2026-10-07',
          plantCount: 12,
          note: note,
        );
      }
      expect(calls, 2);
      api.close();
    },
  );

  test('transfer propagates authoritative server validation errors', () async {
    final api = apiFor(
      (_) async => response({
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Sisa bibit tidak cukup.',
        },
      }, status: 400),
    );
    await expectLater(
      NurseryRepository(api).transferSowing(
        sowingId: 'sem-01',
        tableId: 'meja-01',
        transferDate: '2026-10-07',
        plantCount: 12,
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Sisa bibit tidak cukup.',
        ),
      ),
    );
    api.close();
  });

  testWidgets(
    'requires a table and positive quantity within available capacity',
    (tester) async {
      var posts = 0;
      final api = apiFor((request) async {
        if (request.method == 'POST') posts++;
        return response({
          'data': [
            tableJson(),
            tableJson(id: 'full', capacity: 0),
            tableJson(id: 'maintenance', status: 'pemeliharaan'),
          ],
        });
      });
      await pumpTransfer(tester, api);
      await tester.pumpAndSettle();
      await submit(tester);
      expect(find.text('Pilih meja tujuan.'), findsOneWidget);
      await chooseTable(tester, 'meja-01');
      expect(find.textContaining('Meja full'), findsNothing);
      expect(find.textContaining('Meja maintenance'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, '0');
      await submit(tester);
      expect(find.text('Jumlah tanaman harus lebih dari 0.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '13');
      await submit(tester);
      expect(find.text('Maksimal 12 tanaman untuk meja ini.'), findsOneWidget);
      expect(posts, 0);
      final today = DateUtils.dateOnly(DateTime.now());
      expect(
        find.text(
          'Tanggal pemindahan: ${DateFormat('yyyy-MM-dd').format(today)}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Estimasi panen (+45 hari): ${DateFormat('yyyy-MM-dd').format(today.add(const Duration(days: 45)))}',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );

  testWidgets(
    'date picker changes transfer date and harvest estimate sent to API',
    (tester) async {
      String? sentDate;
      final api = apiFor((request) async {
        if (request.method == 'POST') {
          sentDate = jsonDecode(request.body)['tanggal_pemindahan'] as String;
          return response({'data': {}}, status: 201);
        }
        return response({
          'data': request.url.path.endsWith('/meja-tanam') ? [tableJson()] : [],
        });
      });
      await pumpTransfer(tester, api);
      await tester.pumpAndSettle();
      await chooseTable(tester, 'meja-01');
      await tester.tap(find.textContaining('Tanggal pemindahan:'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      final nextDay = DateUtils.dateOnly(
        DateTime.now(),
      ).add(const Duration(days: 1));
      await tester.enterText(
        find.byType(TextField).last,
        DateFormat('MM/dd/yyyy').format(nextDay),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Estimasi panen (+45 hari): ${DateFormat('yyyy-MM-dd').format(nextDay.add(const Duration(days: 45)))}',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).first, '12');
      await submit(tester);
      await tester.pumpAndSettle();
      expect(sentDate, DateFormat('yyyy-MM-dd').format(nextDay));
      expect(find.text('Pemindahan berhasil disimpan.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );

  testWidgets('shows server rejection and permits corrected submission', (
    tester,
  ) async {
    var posts = 0;
    final api = apiFor((request) async {
      if (request.method == 'POST') {
        posts++;
        return response({
          'error': {'code': 'CAPACITY', 'message': 'Meja sudah penuh.'},
        }, status: 409);
      }
      return response({
        'data': [tableJson()],
      });
    });
    await pumpTransfer(tester, api);
    await tester.pumpAndSettle();
    await chooseTable(tester, 'meja-01');
    await tester.enterText(find.byType(TextFormField).first, '10');
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Meja sudah penuh.'), findsOneWidget);
    expect(find.text('Simpan pemindahan'), findsOneWidget);
    expect(posts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });

  testWidgets(
    'success refreshes both providers; failed refresh can never resubmit POST',
    (tester) async {
      var posts = 0;
      var nurseryGets = 0;
      var tableGets = 0;
      var saved = 0;
      final postResponse = Completer<http.Response>();
      final api = apiFor((request) async {
        if (request.method == 'POST') {
          posts++;
          return postResponse.future;
        }
        if (request.url.path.endsWith('/meja-tanam')) tableGets++;
        if (request.url.path.endsWith('/penyemaian')) nurseryGets++;
        if (posts > 0) {
          return response({
            'error': {'message': 'Koneksi refresh gagal.'},
          }, status: 503);
        }
        return response({
          'data': [tableJson()],
        });
      });
      await pumpTransfer(tester, api, onTransferred: () => saved++);
      await tester.pumpAndSettle();
      await chooseTable(tester, 'meja-01');
      await tester.enterText(find.byType(TextFormField).first, '12');
      await submit(tester);
      await tester.tap(find.text('Menyimpan...'));
      await tester.pump();
      expect(posts, 1);
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);
      postResponse.complete(response({'data': {}}, status: 201));
      await tester.pumpAndSettle();
      expect(saved, 1);
      expect(find.text('Pemindahan berhasil disimpan.'), findsOneWidget);
      expect(find.text('Simpan pemindahan'), findsNothing);
      expect(find.textContaining('Data belum diperbarui.'), findsOneWidget);
      expect(nurseryGets, 1);
      expect(tableGets, 2);
      await tester.tap(find.text('Muat ulang data'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(nurseryGets, 2);
      expect(tableGets, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );

  testWidgets('table states show loading, error retry, then empty state', (
    tester,
  ) async {
    final tables = Completer<http.Response>();
    var calls = 0;
    final api = apiFor((_) async {
      calls++;
      if (calls == 1) return tables.future;
      return response({'data': []});
    });
    await pumpTransfer(tester, api);
    expect(find.text('Memuat meja...'), findsOneWidget);
    tables.complete(
      response({
        'error': {'message': 'Meja gagal dimuat.'},
      }, status: 503),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meja gagal dimuat.'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada meja dengan kapasitas tersedia.'),
      findsOneWidget,
    );
    expect(find.text('Simpan pemindahan'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });

  testWidgets(
    'modal can cancel, blocks dismiss during POST, and locks detail after success',
    (tester) async {
      var posts = 0;
      final posted = Completer<http.Response>();
      final api = apiFor((request) async {
        if (request.method == 'POST') {
          posts++;
          return posted.future;
        }
        if (posts > 0) {
          return response({
            'error': {'message': 'Refresh gagal.'},
          }, status: 503);
        }
        return response({
          'data': [tableJson()],
        });
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            connectedNurseryProvider.overrideWith(
              (ref) => ConnectedNurseryViewModel(
                NurseryRepository(api),
                autoLoad: false,
              ),
            ),
          ],
          child: const MaterialApp(
            home: InfoSeedingPage(sowingRecord: readySowing),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Pindahkan ke Meja'));
      await tester.tap(find.text('Pindahkan ke Meja'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedlingTransferSheet), findsNothing);
      await tester.tap(find.text('Pindahkan ke Meja'));
      await tester.pumpAndSettle();
      await chooseTable(tester, 'meja-01');
      await tester.enterText(find.byType(TextFormField).first, '12');
      await submit(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(SeedlingTransferSheet), findsOneWidget);
      posted.complete(response({'data': {}}, status: 201));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedlingTransferSheet), findsNothing);
      expect(find.text('Pindahkan ke Meja'), findsNothing);
      expect(posts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );

  testWidgets('detail exposes transfer only for ready API sowing', (
    tester,
  ) async {
    const notReady = SowingRecord(
      id: 'sem-02',
      userId: 'usr-01',
      sowingDate: '2026-10-01',
      seedCount: 100,
      status: 'aktif',
      isReadyToMove: false,
    );
    for (final record in [notReady, readySowing]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: InfoSeedingPage(sowingRecord: record)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Pindahkan ke Meja'),
        record.isReadyToMove ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: InfoSeedingPage(
            seedingItem: SeedingBatch(
              id: 'legacy',
              batchName: 'Batch #1',
              variety: 'Selada',
              dateText: '2026-09-01',
              seedCount: 100,
              hss: 20,
              statusLabel: 'Siap pindah',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pindahkan ke Meja'), findsNothing);
  });
}
