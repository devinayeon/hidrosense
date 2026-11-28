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
import 'package:hidrosense_mobile/views/v2/widgets/v2_text_field.dart';
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

/// Kolom `TextField` di dalam `V2TextField` berlabel [label]; dipakai agar test
/// tidak bergantung pada urutan indeks `TextField`.
Finder _fieldByLabel(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(V2TextField)),
  matching: find.byType(TextField),
);

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

  testWidgets('stok minimum harus kurang dari stok awal saat menambah', (
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
      find.text('Stok minimum harus kurang dari stok awal.'),
      findsOneWidget,
    );
    expect(tersimpan, isNull);
    expect(find.text('Tambah barang'), findsOneWidget);
  });

  testWidgets('stok minimum sama dengan stok awal ditolak', (tester) async {
    V2InventarisItem? tersimpan;
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        onSubmit: (item) async {
          tersimpan = item;
        },
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Pupuk A2');
    await tester.enterText(find.byType(TextField).at(1), 'kg');
    await tester.enterText(find.byType(TextField).at(2), '5');
    await tester.enterText(find.byType(TextField).at(3), '5');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Stok minimum harus kurang dari stok awal.'),
      findsOneWidget,
    );
    expect(tersimpan, isNull);
  });

  testWidgets('stok awal 0 ditolak dengan pesan minimal 1', (tester) async {
    V2InventarisItem? tersimpan;
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        onSubmit: (item) async {
          tersimpan = item;
        },
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Pupuk A3');
    await tester.enterText(find.byType(TextField).at(1), 'kg');
    await tester.enterText(find.byType(TextField).at(2), '0');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Stok awal minimal 1.'), findsOneWidget);
    expect(tersimpan, isNull);
    expect(find.text('Tambah barang'), findsOneWidget);
  });

  testWidgets('stok awal desimal di bawah 1 ditolak', (tester) async {
    await _pumpForm(
      tester,
      V2InventarisFormPage(onSubmit: (_) async {}),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Pupuk A4');
    await tester.enterText(find.byType(TextField).at(1), 'kg');
    await tester.enterText(find.byType(TextField).at(2), '0,5');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Stok awal minimal 1.'), findsOneWidget);
  });

  testWidgets('stok awal 10000 diterima', (tester) async {
    V2InventarisItem? tersimpan;
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        onSubmit: (item) async {
          tersimpan = item;
        },
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Pupuk A7');
    await tester.enterText(find.byType(TextField).at(1), 'kg');
    await tester.enterText(find.byType(TextField).at(2), '10000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    expect(tersimpan, isNotNull);
    expect(tersimpan!.jumlah, 10000);
  });

  testWidgets('stok awal 10001 ditolak dengan pesan maksimal 10000', (
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

    await tester.enterText(find.byType(TextField).at(0), 'Pupuk A8');
    await tester.enterText(find.byType(TextField).at(1), 'kg');
    await tester.enterText(find.byType(TextField).at(2), '10001');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Stok awal maksimal 10000.'), findsOneWidget);
    expect(tersimpan, isNull);
    expect(find.text('Tambah barang'), findsOneWidget);
  });

  testWidgets('stok awal 1 tanpa stok minimum tersimpan', (tester) async {
    V2InventarisItem? tersimpan;
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        onSubmit: (item) async {
          tersimpan = item;
        },
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Pupuk A5');
    await tester.enterText(find.byType(TextField).at(1), 'kg');
    await tester.enterText(find.byType(TextField).at(2), '1');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    expect(tersimpan, isNotNull);
    expect(tersimpan!.jumlah, 1);
    expect(tersimpan!.minimum, isNull);
  });

  testWidgets('stok minimum di bawah stok awal diterima', (tester) async {
    V2InventarisItem? tersimpan;
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        onSubmit: (item) async {
          tersimpan = item;
        },
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Pupuk A6');
    await tester.enterText(find.byType(TextField).at(1), 'kg');
    await tester.enterText(find.byType(TextField).at(2), '5');
    await tester.enterText(find.byType(TextField).at(3), '4');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    expect(tersimpan, isNotNull);
    expect(tersimpan!.jumlah, 5);
    expect(tersimpan!.minimum, 4);
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

    // Kolom stok minimum dicari lewat labelnya, bukan urutan indeks.
    await tester.enterText(_fieldByLabel('Stok minimum (opsional)').first, '0');
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

    await tester.enterText(
      _fieldByLabel('Stok minimum (opsional)').first,
      '3,555',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Gunakan maksimal 10 digit dan 2 angka desimal.'),
      findsOneWidget,
    );
  });

  testWidgets('ubah barang menampilkan stok tersedia hanya-baca', (
    tester,
  ) async {
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        initialItem: designDetailBiasa,
        onSubmit: (_) async {},
      ),
    );

    expect(find.text('Stok tersedia'), findsOneWidget);
    expect(find.text('12 pak'), findsOneWidget);
    expect(find.text('Stok diubah lewat Catat stok.'), findsOneWidget);

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, '12 pak'),
    );
    expect(field.enabled, isFalse);
  });

  testWidgets('ubah barang jenis obat menampilkan kolom stok minimum', (
    tester,
  ) async {
    const obat = V2InventarisItem(
      id: 'stok-obat-1',
      nama: 'Pestisida Nabati',
      jenis: V2JenisBarang.obat,
      jumlah: 5,
      satuan: 'botol',
      minimum: 2,
      medicineId: 'katalog-1',
      medicineName: 'Pestisida Nabati',
      medicineKatalog: true,
    );
    await _pumpForm(
      tester,
      V2InventarisFormPage(initialItem: obat, onSubmit: (_) async {}),
    );

    expect(find.text('Nama barang'), findsNothing);
    expect(find.widgetWithText(V2SelectField, 'Obat'), findsOneWidget);
    expect(find.text('Stok minimum (opsional)'), findsOneWidget);
    expect(find.text('Stok tersedia'), findsOneWidget);
    expect(find.text('5 botol'), findsOneWidget);
  });

  testWidgets('ubah barang menolak stok minimum sama dengan stok tersedia', (
    tester,
  ) async {
    V2InventarisItem? tersimpan;
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        initialItem: designDetailBiasa,
        onSubmit: (item) async {
          tersimpan = item;
        },
      ),
    );

    await tester.enterText(
      _fieldByLabel('Stok minimum (opsional)').first,
      '12',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Stok minimum harus kurang dari stok tersedia.'),
      findsOneWidget,
    );
    expect(tersimpan, isNull);
    expect(find.text('Ubah barang'), findsOneWidget);
  });

  testWidgets('ubah barang menolak stok minimum melebihi stok tersedia', (
    tester,
  ) async {
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        initialItem: designDetailBiasa,
        onSubmit: (_) async {},
      ),
    );

    await tester.enterText(
      _fieldByLabel('Stok minimum (opsional)').first,
      '13',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Stok minimum harus kurang dari stok tersedia.'),
      findsOneWidget,
    );
  });

  testWidgets('ubah barang menerima stok minimum kurang dari stok tersedia', (
    tester,
  ) async {
    V2InventarisItem? tersimpan;
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        initialItem: designDetailBiasa,
        onSubmit: (item) async {
          tersimpan = item;
        },
      ),
    );

    await tester.enterText(
      _fieldByLabel('Stok minimum (opsional)').first,
      '11',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    // Dialog "Simpan perubahan barang?".
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Simpan'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tersimpan, isNotNull);
    expect(tersimpan!.minimum, 11);
  });

  testWidgets('ubah barang stok rendah tetap bisa disimpan bila minimum tetap', (
    tester,
  ) async {
    V2InventarisItem? tersimpan;
    await _pumpForm(
      tester,
      V2InventarisFormPage(
        initialItem: designDetailMenipis,
        onSubmit: (item) async {
          tersimpan = item;
        },
      ),
    );

    // Stok 2, minimum 3 (sudah di bawah stok). Minimum tidak disentuh, jadi
    // batas atas tidak berlaku dan simpan tetap lolos.
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Simpan'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tersimpan, isNotNull);
    expect(tersimpan!.minimum, 3);
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