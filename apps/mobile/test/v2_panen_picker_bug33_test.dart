// Regresi BUG-33: pemilih tanaman di form "Catat panen" tidak bisa dipakai saat
// data banyak/berantakan/duplikat. Uji ini memeriksa: (1) baris ganda dibuang
// dan batch tanpa tanaman aktif disaring, urut siap panen lebih dulu; (2) tiap
// baris membedakan batch (asal semaian, tanggal pindah, HSS, sisa aktif);
// (3) sheet bisa dicari/filter dan digulir; (4) aman pada skala teks 2.0.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_panen_data.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_panen_connected.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_tanaman_sheet.dart';

TransferRecord _transfer(
  String id, {
  int active = 10,
  String table = '1',
  int? hss = 30,
  int? sisa,
  String date = '2026-11-01',
}) => TransferRecord(
  id: id,
  tableId: table,
  sowingId: '5',
  transferDate: date,
  plantCount: 100,
  activePlants: active,
  hss: hss,
  remainingHarvestDays: sisa,
);

Finder _cariField() => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'Nama meja atau varietas',
);

void main() {
  test('daftar estimasi buang duplikat, saring aktif=0, urut siap panen/HSS', () {
    final hasil = v2DaftarEstimasiPanen(
      transfers: [
        _transfer('3', active: 40, sisa: 20),
        _transfer('1', active: 0, sisa: 0), // tanpa tanaman aktif -> dibuang
        _transfer('2', active: 10, sisa: 5),
        _transfer('3', active: 40, sisa: 20), // duplikat id -> tampil sekali
        _transfer('4', active: 8, sisa: 0), // siap panen -> di atas
      ],
      tables: const [],
    );

    expect(hasil.map((e) => e.transferId).toList(), ['4', '2', '3']);
  });

  test('estimasi dari transfer memuat tanggal pindah dan HSS', () {
    final item = v2DaftarEstimasiPanen(
      transfers: [
        _transfer('7', hss: 12, date: '2026-11-05', sisa: 3),
      ],
      tables: const [],
    ).single;

    expect(item.transferDate, DateTime(2026, 11, 5));
    expect(item.hss, 12);
    expect(item.sowingLabel, 'Batch #5');
    expect(item.labelRincian, contains('Asal Batch #5'));
    expect(item.labelRincian, contains('Pindah 5 Nov'));
    expect(item.labelRincian, contains('HSS 12'));
    expect(item.labelRincian, contains('Sisa 10'));
  });

  test('saring pilihan buang duplikat dan saring per teks/meja', () {
    final items = <V2PanenEstimasi>[
      const V2PanenEstimasi(
        meja: 'Meja B1',
        varietas: 'Romaine',
        jumlahTanaman: 240,
        hariLagi: 0,
        transferId: '1',
      ),
      const V2PanenEstimasi(
        meja: 'Meja B1',
        varietas: 'Romaine',
        jumlahTanaman: 240,
        hariLagi: 0,
        transferId: '1', // duplikat
      ),
      const V2PanenEstimasi(
        meja: 'Meja A2',
        varietas: 'Butterhead',
        jumlahTanaman: 40,
        hariLagi: 9,
        transferId: '2',
      ),
    ];

    expect(saringPilihanTanamanPanen(items).map((e) => e.transferId), ['1', '2']);
    expect(
      saringPilihanTanamanPanen(items, cari: 'butter').map((e) => e.transferId),
      ['2'],
    );
    expect(
      saringPilihanTanamanPanen(items, meja: 'Meja B1').map((e) => e.transferId),
      ['1'],
    );
  });

  test('kunci baris memakai id pemindahan bila ada', () {
    const item = V2PanenEstimasi(
      meja: 'Meja B1',
      varietas: 'Romaine',
      jumlahTanaman: 240,
      hariLagi: 0,
      transferId: '9',
    );
    expect(item.kunci, '9');
    const galeri = V2PanenEstimasi(
      meja: 'Meja B1',
      varietas: 'Romaine',
      jumlahTanaman: 240,
      hariLagi: 0,
    );
    expect(galeri.kunci, 'Meja B1|Romaine');
  });

  List<V2PanenEstimasi> banyak() => <V2PanenEstimasi>[
    for (var i = 1; i <= 300; i++)
      V2PanenEstimasi(
        meja: 'Meja M${(i % 12) + 1}',
        varietas: 'Varietas ${i % 7}',
        jumlahTanaman: 10 + i,
        hariLagi: i % 40,
        transferId: '$i',
      ),
    // 5 id pemindahan yang muncul dua kali (data server/uji berulang).
    for (var i = 1; i <= 5; i++)
      V2PanenEstimasi(
        meja: 'Meja M${(i % 12) + 1}',
        varietas: 'Varietas ${i % 7}',
        jumlahTanaman: 10 + i,
        hariLagi: i % 40,
        transferId: '$i',
      ),
    const V2PanenEstimasi(
      meja: 'Meja Unik',
      varietas: 'Zukini',
      jumlahTanaman: 77,
      hariLagi: 2,
      transferId: '999',
    ),
    const V2PanenEstimasi(
      meja: 'Meja Unik',
      varietas: 'Zukini',
      jumlahTanaman: 77,
      hariLagi: 2,
      transferId: '999', // duplikat
    ),
  ];

  Future<List<V2PanenItem?>> buka(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final box = <V2PanenItem?>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, w) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: w!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                box.add(
                  await Navigator.of(context).push<V2PanenItem>(
                    V2PanenFormPage.route(
                      pilihan: banyak(),
                      initialDate: DateTime(2026, 11, 15),
                    ),
                  ),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    return box;
  }

  testWidgets('sheet pemilih bisa dicari, dedup, dan memilih batch benar', (
    tester,
  ) async {
    final box = await buka(tester, 1);

    await tester.tap(find.text('Pilih tanaman'));
    await tester.pumpAndSettle();

    // Daftar digulir (bukan Column yang meluber) supaya ratusan batch aman.
    expect(find.byType(ListView), findsOneWidget);

    await tester.enterText(_cariField(), 'Zukini');
    await tester.pumpAndSettle();

    // Duplikat id 999 dibuang: hanya satu baris "Meja Unik, Zukini".
    expect(find.text('Meja Unik, Zukini'), findsOneWidget);

    await tester.tap(find.text('Meja Unik, Zukini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();

    expect(find.text('Meja Unik, Zukini'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '10');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(box, isNotEmpty);
    expect(box.last, isNotNull);
    expect(box.last!.transferId, '999');
    expect(box.last!.meja, 'Meja Unik');
  });

  testWidgets('sheet pemilih aman pada skala teks 2.0', (tester) async {
    await buka(tester, 2);
    await tester.tap(find.text('Pilih tanaman'));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
