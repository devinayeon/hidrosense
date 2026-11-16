// Tes formulir penjualan saat hasil kiriman belum pasti: isian dipulihkan dan
// dikunci, lalu dikirim ulang dengan kunci yang sama supaya tidak tercatat dua kali.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:hidrosense_mobile/data/models/sale_record.dart';
import 'package:hidrosense_mobile/data/repositories/harvest_repository.dart';
import 'package:hidrosense_mobile/data/repositories/sales_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/models/penjualan_model.dart';
import 'package:hidrosense_mobile/viewmodels/catat_penjualan_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/penjualan_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/sale_command.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/catat_penjualan_body.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';

import 'support/harvest_fixture.dart';
import 'support/sales_fixture.dart';

const _draft = SalesDraft(
  date: '2026-11-01',
  buyer: 'Toko Baru',
  status: 'lunas',
  harvestId: '7',
  quantity: 2.5,
  price: 1000,
  priceWireInput: '1000.00',
  note: 'bayar tunai',
);

const _user = SessionUser(
  id: '1',
  name: 'Petani',
  username: 'petani',
  role: 'petani',
  permissions: ['penjualan:read', 'penjualan:write'],
);

http.Response _page() => http.Response(
  jsonEncode({
    'data': <Object>[],
    'meta': {'page': 1, 'limit': 100, 'total': 0, 'total_pages': 0},
  }),
  200,
);

http.Response _saved() => http.Response(
  jsonEncode({
    'data': saleJson(
      id: '9',
      date: '2026-11-01',
      buyer: 'Toko Baru',
      note: 'bayar tunai',
      details: [
        saleDetailJson(harvestId: '7', quantity: '2.50', price: '1000.00'),
      ],
    ),
    'operation': {'operation_key': 'x', 'revision': '1'},
    'replayed': true,
  }),
  200,
);

SalesDraft _draftKg(double quantity) => SalesDraft(
  date: '2026-11-01',
  buyer: 'Toko',
  status: 'lunas',
  harvestId: '7',
  quantity: quantity,
  price: 1000,
  priceWireInput: '1000.00',
);

ProviderContainer _containerFor(ApiClient api) => ProviderContainer(
  overrides: [
    apiClientProvider.overrideWithValue(api),
    sessionProvider.overrideWith(
      (ref) =>
          SessionViewModel(api, initialState: const SessionState(user: _user)),
    ),
  ],
);

/// Membuka formulir sebagai halaman, supaya penutupan setelah berhasil bisa diuji.
Future<void> _pumpForm(
  WidgetTester tester,
  ProviderContainer container,
  GlobalKey<NavigatorState> navigator, {
  PenjualanItem? item,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.lightTheme,
        home: const SizedBox.shrink(),
      ),
    ),
  );
  navigator.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: CatatPenjualanBody(itemToEdit: item)),
    ),
  );
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness(
    http.Response Function(int attempt) reply, {
    List<Map<String, dynamic>> harvests = const [],
  }) {
    api = salesApi((request) async {
      if (request.method == 'GET') {
        return request.url.path.endsWith('/panen')
            ? harvestPage(harvests)
            : _page();
      }
      keys.add(request.headers['Idempotency-Key'] ?? '<none>');
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (keys.length == 1) throw http.ClientException('connection reset');
      return reply(keys.length);
    });
    container = _containerFor(api);
  }

  final keys = <String>[];
  final bodies = <Map<String, dynamic>>[];
  final navigator = GlobalKey<NavigatorState>();
  late final ApiClient api;
  late final ProviderContainer container;

  /// Mengirim penjualan pertama yang responsnya hilang, lalu membuka formulir.
  Future<void> open(WidgetTester tester, {PenjualanItem? item}) async {
    addTearDown(container.dispose);
    final listener = container.listen(penjualanViewModelProvider, (_, _) {});
    addTearDown(listener.close);
    await tester.runAsync(() async {
      try {
        await container
            .read(penjualanViewModelProvider.notifier)
            .createSale(_draft);
      } catch (_) {}
    });
    await _pumpForm(tester, container, navigator, item: item);
  }
}

void main() {
  testWidgets('isian dipulihkan, dikunci, dan dikirim ulang dengan kunci sama', (
    tester,
  ) async {
    final harness = _Harness((_) => _saved());
    await harness.open(tester);

    expect(find.text('Toko Baru'), findsOneWidget);
    expect(find.text('2.5'), findsOneWidget);
    expect(find.text('1000.00'), findsOneWidget);
    expect(find.text('bayar tunai'), findsOneWidget);
    expect(find.text('Lunas'), findsOneWidget);
    expect(find.text('Panen #7'), findsOneWidget);
    expect(find.textContaining('mungkin sudah tersimpan'), findsOneWidget);
    // Stok asli belum tentu termuat; berat isian tidak boleh tampil sebagai stok.
    expect(find.textContaining('Stok tersedia'), findsNothing);
    // Papan ketik fisik tidak tertahan IgnorePointer, jadi kolomnya read-only.
    for (final text in ['Toko Baru', '2.5', '1000.00', 'bayar tunai']) {
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, text)).readOnly,
        isTrue,
        reason: text,
      );
    }
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const ValueKey('sale-form-fields')))
          .ignoring,
      isTrue,
    );

    await tester.tap(find.text('Kirim Ulang Penjualan'));
    await tester.pumpAndSettle();

    expect(harness.keys.length, 2);
    expect(harness.keys[1], harness.keys[0]);
    expect(harness.bodies[1], harness.bodies[0]);
    expect(harness.container.read(saleCommandsProvider), isEmpty);
    // Berhasil: formulir tertutup dan penjualan tampil di daftar.
    expect(find.byType(CatatPenjualanBody), findsNothing);
  });

  testWidgets(
    'ditolak jelas saat dikirim ulang: kunci lepas dan formulir terbuka',
    (tester) async {
      final harness = _Harness(
        (_) => http.Response(
          jsonEncode({
            'error': {
              'code': 'SALE_EXCEEDS_HARVEST_STOCK',
              'message': 'Berat jual melebihi stok panen.',
            },
          }),
          409,
        ),
      );
      await harness.open(tester);

      await tester.tap(find.text('Kirim Ulang Penjualan'));
      await tester.pumpAndSettle();

      expect(harness.keys.length, 2);
      expect(harness.container.read(saleCommandsProvider), isEmpty);
      expect(find.text('Berat jual melebihi stok panen.'), findsOneWidget);
      expect(find.text('Simpan Penjualan'), findsOneWidget);
      expect(find.textContaining('mungkin sudah tersimpan'), findsNothing);
      expect(find.textContaining('Stok tersedia'), findsNothing);
      expect(
        harness.container.read(catatPenjualanViewModelProvider).selectedBatch,
        isNull,
      );
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('sale-form-fields')),
            )
            .ignoring,
        isFalse,
      );
    },
  );

  // Kiriman ulang bisa terus gagal, misalnya jawaban rusak yang selalu sama.
  // Pengguna harus punya jalan keluar yang sadar, bukan terkunci selamanya.
  testWidgets('buang isian: minta konfirmasi, lalu formulir terbuka lagi', (
    tester,
  ) async {
    final harness = _Harness((_) => http.Response('<html>portal</html>', 200));
    await harness.open(tester);

    await tester.tap(find.text('Kirim Ulang Penjualan'));
    await tester.pumpAndSettle();
    expect(harness.keys.length, 2);
    // Jawaban 200 berisi HTML bisa datang dari portal Wi-Fi: tetap belum pasti.
    expect(harness.container.read(saleCommandsProvider), isNotEmpty);
    expect(find.text('Kirim Ulang Penjualan'), findsOneWidget);

    await tester.tap(find.text('Buang Isian Ini'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Periksa daftar penjualan'), findsOneWidget);

    // Batal: tidak ada yang berubah.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(harness.container.read(saleCommandsProvider), isNotEmpty);

    await tester.tap(find.text('Buang Isian Ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, Buang'));
    await tester.pumpAndSettle();
    expect(harness.container.read(saleCommandsProvider), isEmpty);
    expect(find.text('Simpan Penjualan'), findsOneWidget);
    expect(find.text('Buang Isian Ini'), findsNothing);
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const ValueKey('sale-form-fields')))
          .ignoring,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Toko Baru'))
          .readOnly,
      isFalse,
    );
    // Batch tiruan dilepas: pengguna memilih batch asli dengan stok asli.
    expect(find.textContaining('Stok tersedia'), findsNothing);
    expect(find.text('Panen #7'), findsNothing);
    final form = harness.container.read(catatPenjualanViewModelProvider);
    expect(form.selectedBatch, isNull);
  });

  testWidgets('kuncian lepas dan batch ada di daftar: stok asli yang tampil', (
    tester,
  ) async {
    final harness = _Harness(
      (_) => _saved(),
      harvests: [saleHarvestJson(id: '7', layak: '100.00')],
    );
    await harness.open(tester);
    expect(find.textContaining('Stok tersedia'), findsNothing);

    await tester.tap(find.text('Buang Isian Ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, Buang'));
    await tester.pumpAndSettle();

    final form = harness.container.read(catatPenjualanViewModelProvider);
    expect(form.selectedBatch?.id, '7');
    expect(form.selectedBatch?.stokTersedia, 100);
    expect(find.text('Stok tersedia: 100 Kg'), findsOneWidget);
  });

  testWidgets('kiriman yang masih berjalan: tanpa peringatan, tidak terkunci', (
    tester,
  ) async {
    final gate = Completer<http.Response>();
    final api = salesApi(
      (request) async => request.method == 'GET' ? _page() : gate.future,
    );
    final container = _containerFor(api);
    addTearDown(container.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await _pumpForm(tester, container, navigator);
    final vm = container.read(penjualanViewModelProvider.notifier);
    unawaited(vm.createSale(_draft).then((_) {}, onError: (_) {}));
    container.read(catatPenjualanViewModelProvider.notifier).setCatatan('x');
    await tester.pump();

    expect(find.textContaining('mungkin sudah tersimpan'), findsNothing);
    expect(find.text('Buang Isian Ini'), findsNothing);
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const ValueKey('sale-form-fields')))
          .ignoring,
      isFalse,
    );
    // Kiriman yang sedang berjalan juga tidak bisa dibuang.
    vm.discardPending();
    expect(container.read(saleCommandsProvider), isNotEmpty);
    gate.complete(_saved());
    await tester.pumpAndSettle();
    expect(container.read(saleCommandsProvider), isEmpty);
  });

  testWidgets('formulir transaksi lain: tombol mati dan menjelaskan sebabnya', (
    tester,
  ) async {
    final harness = _Harness((_) => _saved());
    await harness.open(
      tester,
      item: const PenjualanItem(
        id: '3',
        pembeli: 'Toko Lama',
        tanggal: '1 Nov',
        tanggalIso: '2026-11-01',
        kuantitas: '1 Kg',
        totalHarga: 1000,
        status: StatusPenjualan.lunas,
        version: '1',
        details: [
          PenjualanLine(
            idPanen: '7',
            tanggalPanen: '2026-10-20',
            jumlahKg: 1,
            hargaPerKg: 1000,
            hargaPerKgWire: '1000.00',
            totalHarga: 1000,
          ),
        ],
      ),
    );

    expect(find.text('Toko Lama'), findsOneWidget);
    // Pesan menyebut transaksi mana yang tertahan dan cara menyelesaikannya.
    expect(find.textContaining('Toko Baru'), findsOneWidget);
    expect(find.textContaining('Catat Penjualan'), findsOneWidget);
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
    expect(harness.keys.length, 1);

    // Jalan keluar bila transaksi itu tidak bisa dibuka lagi.
    await tester.tap(find.text('Buang Isian Ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, Buang'));
    await tester.pumpAndSettle();
    expect(harness.container.read(saleCommandsProvider), isEmpty);
    expect(find.textContaining('Toko Baru'), findsNothing);
    expect(find.text('Toko Lama'), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const ValueKey('sale-form-fields')))
          .ignoring,
      isFalse,
    );
  });

  test('kirim ulang koreksi: stok dihitung dengan baris lama', () async {
    final api = salesApi((_) async => throw StateError('Unexpected'));
    final sales = FakeSalesRepository(api)
      ..records = [
        saleRecord(
          id: '3',
          details: [saleDetailJson(harvestId: '7', quantity: '5.00')],
        ),
      ];
    final harvest = FakeHarvestRepository(api)
      ..records = [saleHarvest(id: '7', layak: '100.00')];
    final vm = PenjualanViewModel(sales, harvest, autoLoad: false);
    addTearDown(vm.dispose);
    await vm.refresh();
    expect(vm.state.batches.single.stokTersedia, 95);

    final item = vm.state.items.single;
    sales.writeError = http.ClientException('connection reset');
    await expectLater(vm.updateSale(item, _draftKg(7)), throwsA(anything));
    sales.writeError = null;
    // Daftar tidak bisa dimuat ulang, jadi angka stok murni dari perhitungan lokal.
    sales.loadError = const ApiException(503, 'X', 'x');
    await vm.retryPending();

    // 95 + 5 (baris lama dikembalikan) - 7 (baris baru).
    expect(vm.state.batches.single.stokTersedia, 93);
  });

  test('pengguna lain tidak ikut terkunci dan memakai kunci sendiri', () async {
    final keys = <String>[];
    final api = salesApi((request) async {
      keys.add(request.headers['Idempotency-Key'] ?? '<none>');
      throw http.ClientException('connection reset');
    });
    final commands = <SaleCommandScope, SaleCommand>{};
    PenjualanViewModel forUser(String id) => PenjualanViewModel(
      SalesRepository(api),
      HarvestRepository(api),
      autoLoad: false,
      userId: id,
      commands: commands,
    );
    await expectLater(forUser('1').createSale(_draft), throwsA(anything));
    await expectLater(forUser('2').createSale(_draft), throwsA(anything));
    expect(keys.length, 2);
    expect(keys[0], isNot(keys[1]));
    expect(commands.length, 2);
  });

  test(
    'koreksi dikirim ulang dengan versi lama walau versi di layar naik',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final keys = <String>[];
      final api = salesApi((request) async {
        keys.add(request.headers['Idempotency-Key'] ?? '<none>');
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        throw http.ClientException('connection reset');
      });
      final vm = PenjualanViewModel(
        SalesRepository(api),
        HarvestRepository(api),
        autoLoad: false,
      );
      PenjualanItem item(String version) => PenjualanItem(
        id: '3',
        pembeli: 'Toko',
        tanggal: '1 Nov',
        tanggalIso: '2026-11-01',
        kuantitas: '1 Kg',
        totalHarga: 1000,
        status: StatusPenjualan.lunas,
        version: version,
        details: const [
          PenjualanLine(
            idPanen: '7',
            tanggalPanen: '2026-10-20',
            jumlahKg: 1,
            hargaPerKg: 1000,
            hargaPerKgWire: '1000.00',
            totalHarga: 1000,
          ),
        ],
      );
      await expectLater(vm.updateSale(item('1'), _draft), throwsA(anything));
      await expectLater(vm.updateSale(item('2'), _draft), throwsA(anything));
      expect(bodies.map((body) => body['expected_version']), ['1', '1']);
      expect(keys[1], keys[0]);
    },
  );
}
