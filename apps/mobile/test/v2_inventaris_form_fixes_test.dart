// Regresi sesi 10: aturan form inventaris (nama unik, stok minimum, obat dari
// katalog) dan tombol aktifkan kembali untuk barang arsip.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_inventaris_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inventaris_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inventaris_form_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_select_field.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> _pumpForm(
  WidgetTester tester,
  Widget form, {
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: form));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('jenis Obat menyembunyikan Nama barang dan wajib memilih obat', (
    tester,
  ) async {
    await _pumpForm(tester, const V2InventarisFormPage.create());

    expect(find.text('Nama barang'), findsOneWidget);
    await tester.tap(find.text('Obat'));
    await tester.pumpAndSettle();

    expect(find.text('Nama barang'), findsNothing);
    expect(find.widgetWithText(V2SelectField, 'Obat'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih obat'), findsOneWidget);
    expect(find.text('Tambah barang'), findsOneWidget);
  });

  testWidgets('stok minimum tidak boleh melebihi stok awal saat menambah', (
    tester,
  ) async {
    V2InventarisItem? tersimpan;
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        onSubmit: (item) async {
          tersimpan = item;
        },
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Pupuk A');
    await tester.enterText(find.byType(TextField).at(1), 'kg');
    await tester.enterText(find.byType(TextField).at(2), '5');
    await tester.enterText(find.byType(TextField).at(3), '10');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Stok minimum tidak boleh melebihi stok awal.'),
      findsOneWidget,
    );
    expect(tersimpan, isNull);
    expect(find.text('Tambah barang'), findsOneWidget);
  });

  testWidgets('stok awal menolak bentuk angka yang tidak sah', (tester) async {
    await _pumpForm(
      tester,
      V2InventarisFormPage(onSubmit: (_) async {}),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Pupuk B');
    await tester.enterText(find.byType(TextField).at(1), 'kg');
    await tester.enterText(find.byType(TextField).at(2), '1.234');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Gunakan maksimal 10 digit dan 2 angka desimal.'),
      findsOneWidget,
    );
  });

  testWidgets('ubah barang menampilkan galat stok minimum di form (K-24)', (
    tester,
  ) async {
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        initialItem: designDetailBiasa,
        onSubmit: (_) async {},
      ),
    );

    // Nama (0), Satuan (1, terkunci), Stok minimum (2).
    await tester.enterText(find.byType(TextField).at(2), '0');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Stok minimum harus lebih dari 0.'), findsOneWidget);
    expect(find.text('Ubah barang'), findsOneWidget);
  });

  testWidgets('ubah barang menolak bentuk angka stok minimum yang salah', (
    tester,
  ) async {
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        initialItem: designDetailBiasa,
        onSubmit: (_) async {},
      ),
    );

    await tester.enterText(find.byType(TextField).at(2), '3,555');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Gunakan maksimal 10 digit dan 2 angka desimal.'),
      findsOneWidget,
    );
  });

  testWidgets('nama barang duplikat dari server tampil di kolom nama', (
    tester,
  ) async {
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        onSubmit: (_) async => throw const ApiException(
          409,
          'INVENTARIS_NAME_TAKEN',
          'Nama barang sudah dipakai.',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Pupuk A');
    await tester.enterText(find.byType(TextField).at(1), 'kg');
    await tester.enterText(find.byType(TextField).at(2), '5');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('Nama barang sudah dipakai.'), findsOneWidget);
    expect(find.text('Tambah barang'), findsOneWidget);
  });

  testWidgets('detail barang arsip punya tombol Aktifkan kembali', (
    tester,
  ) async {
    var diaktifkan = false;
    await _pumpForm(
      tester,
      V2InventarisDetailPage(
        item: designDetailArsip,
        showAksi: false,
        onAktifkan: () => diaktifkan = true,
      ),
    );

    expect(find.text('Aktifkan kembali'), findsOneWidget);
    await tester.tap(find.text('Aktifkan kembali'));
    await tester.pump();
    expect(diaktifkan, isTrue);
  });

  test('repository mengirim id_katalog dan memanggil endpoint activate', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'data': {
              'id_inventaris': '1',
              'public_id': null,
              'version': null,
              'id_jenis_inventaris': '1',
              'id_obat': null,
              'id_katalog': '7',
              'nama_barang': 'Spinosad',
              'satuan': 'botol',
              'stok_minimum': '2',
              'status_aktif': 1,
              'nama_jenis': 'Obat & Pestisida',
              'nama_obat': null,
              'nama_katalog': 'Spinosad',
              'saldo': '0',
              'di_bawah_minimum': true,
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUri: Uri.parse('https://example.test/api/v1'),
    )..setTokens(accessToken: 'a', refreshToken: 'r');
    addTearDown(api.close);
    final repo = InventoryRepository(
      api,
      Completer<InventoryCache>().future,
      userId: '1',
    );

    await repo.createItem(
      categoryId: '1',
      katalogId: '7',
      name: 'Spinosad',
      unit: 'botol',
      minimum: '2',
    );
    await repo.activateItem('1');

    expect(
      jsonDecode(requests[0].body),
      containsPair('id_katalog', '7'),
    );
    expect(
      jsonDecode(requests[0].body),
      isNot(contains('id_obat')),
    );
    expect(requests[1].url.path, '/api/v1/inventaris/1/activate');
  });
}