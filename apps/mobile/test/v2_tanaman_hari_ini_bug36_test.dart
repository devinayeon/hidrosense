// Regresi BUG-36: tanaman tersambung tidak boleh memakai tanggal contoh
// (15 Nov 2026) untuk HST, hitung mundur panen, atau perkiraan panen halaman
// sukses "Pindah ke meja".
//
// Bukti gagal di kode lama:
// - `V2TanamanItem.hariIni` dan `v2MejaItemFromRecord(hariIni:)` belum ada,
//   jadi dua tes pertama tidak ter-compile di kode lama; nilainya pun akan
//   dihitung dari 15 Nov 2026 (`satuan` berbeda jauh).
// - Halaman sukses pindah selalu menampilkan "Panen sekitar 30 Des.".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/table_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_data.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_meja_connected.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindah_meja_page.dart';

void main() {
  test('V2TanamanItem memakai hariIni untuk HST & hitung mundur panen (BUG-36)',
      () {
    final tersambung = V2TanamanItem(
      varietas: 'Romaine',
      tanggalTanam: DateTime(2027, 1, 10),
      tanggalPanen: DateTime(2027, 2, 24),
      tanggalPindah: DateTime(2027, 1, 10),
      hariIni: DateTime(2027, 1, 20),
    );
    expect(tersambung.hst, 10);
    expect(tersambung.hariMenujuPanen, 35);
    expect(tersambung.labelPanenLengkap, 'Panen 24 Feb. 35 hari lagi.');

    // Tanpa hariIni tetap memakai acuan galeri 15 Nov 2026 (frame 6.21).
    final galeri = V2TanamanItem(
      varietas: 'Romaine',
      tanggalTanam: DateTime(2026, 11, 7),
      tanggalPanen: DateTime(2026, 12, 22),
      tanggalPindah: DateTime(2026, 11, 7),
    );
    expect(galeri.hst, 8);
    expect(galeri.hariMenujuPanen, 37);
  });

  test('meja tersambung memakai hari ini nyata, bukan 15 Nov 2026 (BUG-36)', () {
    const record = TableRecord(
      id: '1',
      code: 'A1',
      holeCount: 200,
      status: 'tersedia',
      activePlants: 120,
      availableCapacity: 80,
    );
    final transfer = TransferRecord(
      id: '5',
      tableId: '1',
      sowingId: '7',
      transferDate: '2027-01-10',
      plantCount: 120,
      activePlants: 120,
      estimatedHarvestDate: '2027-02-24',
    );
    final meja = v2MejaItemFromRecord(
      record,
      transfers: [transfer],
      hariIni: DateTime(2027, 1, 20),
    );
    final tanaman = meja.tanaman.single;
    expect(tanaman.hst, 10);
    expect(tanaman.hariMenujuPanen, 35);
  });

  testWidgets('perkiraan panen halaman sukses pindah ikut tanggal pindah (BUG-36)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: V2PindahMejaFormPage(
          item: designSemaianRomaineSiapPindah,
          initialDate: DateTime(2027, 1, 6),
          daftarMeja: const [
            V2SemaianMeja(nama: 'Meja A2', lubangKosong: 400, tableId: '2'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pindahkan'));
    await tester.pumpAndSettle();

    // 6 Jan + 45 HST = 20 Feb, bukan "30 Des" tetap.
    expect(find.textContaining('Panen sekitar 20 Feb.'), findsOneWidget);
    expect(find.textContaining('30 Des'), findsNothing);
  });
}
