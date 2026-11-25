// Regresi BUG-47: catatan tanaman tersimpan di batch pemindahan, tetapi tidak
// pernah tampil di halaman Detail tanaman.
//
// Bukti gagal di kode lama: kartu info hanya berisi "Tanaman aktif" dan
// "Pindah", sehingga teks catatan tidak ditemukan.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_detail_tanaman_page.dart';

void main() {
  testWidgets('catatan tanaman tampil di Detail tanaman (BUG-47)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tanaman = V2TanamanItem(
      varietas: 'Romaine',
      tanggalTanam: DateTime(2026, 11, 8),
      tanggalPanen: DateTime(2026, 12, 23),
      tanggalPindah: DateTime(2026, 11, 8),
      keterangan: 'Rak 2, dekat pintu',
      transferId: '5',
      hariIni: DateTime(2026, 11, 25),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: V2DetailTanamanPage(
            tanaman: tanaman,
            meja: const V2MejaItem(
              id: '1',
              kode: 'A2',
              jumlahLubang: 240,
              terisi: 40,
              status: V2MejaStatus.tersedia,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catatan'), findsOneWidget);
    expect(find.text('Rak 2, dekat pintu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}