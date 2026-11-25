// Fitur-2 (D-27): daftar meja di form "Pindah ke meja" diurutkan — meja
// tersedia dulu (lubang kosong terbanyak, lalu kode meja), meja penuh/perawatan
// di bawah dan tetap disabled. Pilihan awal (mis. "Tambah tanaman") tetap
// menunjuk meja yang benar setelah urutan berubah.
//
// Bukti gagal di kode lama: helper `urutkanMejaPindah` belum ada; daftar form
// memakai urutan apa adanya dari pemanggil.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindah_meja_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_option_row.dart';

void main() {
  test('urutkan meja: tersedia dulu, lubang terbanyak, penuh/perawatan di bawah',
      () {
    final hasil = urutkanMejaPindah(const <V2SemaianMeja>[
      V2SemaianMeja(nama: 'Meja D1', perawatan: true),
      V2SemaianMeja(nama: 'Meja C1', lubangKosong: 50),
      V2SemaianMeja(nama: 'Meja B1', penuh: true),
      V2SemaianMeja(nama: 'Meja A3', lubangKosong: 120),
      V2SemaianMeja(nama: 'Meja A2', lubangKosong: 120),
    ]);

    expect(
      hasil.map((meja) => meja.nama).toList(),
      ['Meja A2', 'Meja A3', 'Meja C1', 'Meja B1', 'Meja D1'],
    );
    // Dua meja lubang sama diurut kode meja (A2 sebelum A3).
    expect(hasil.last.tersedia, isFalse);
  });

  testWidgets('daftar form mengikuti urutan D-27 dan pilihan awal tetap benar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: V2PindahMejaFormPage(
          item: designSemaianRomaineSiapPindah,
          // Meja awal (index 2) = Meja C1, sengaja di tengah daftar mentah.
          mejaAwal: 2,
          daftarMeja: const <V2SemaianMeja>[
            V2SemaianMeja(nama: 'Meja D1', perawatan: true),
            V2SemaianMeja(nama: 'Meja B1', penuh: true),
            V2SemaianMeja(
              nama: 'Meja C1',
              lubangKosong: 50,
              tableId: 'c1',
            ),
            V2SemaianMeja(
              nama: 'Meja A2',
              lubangKosong: 200,
              tableId: 'a2',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rows = tester
        .widgetList<V2OptionRow>(find.byType(V2OptionRow))
        .toList();
    final nama = rows.map((row) => row.label.split(',').first).toList();
    expect(nama, ['Meja A2', 'Meja C1', 'Meja B1', 'Meja D1']);

    // Meja penuh/perawatan tetap disabled.
    final disabled = rows
        .where((row) => row.state == V2OptionState.disabled)
        .map((row) => row.label.split(',').first)
        .toList();
    expect(disabled, containsAll(['Meja D1', 'Meja B1']));

    // Pilihan awal tetap Meja C1 walau urutannya berubah (D-25/D-27).
    final terpilih = rows
        .where((row) => row.state == V2OptionState.selected)
        .map((row) => row.label.split(',').first)
        .toList();
    expect(terpilih, ['Meja C1']);
  });
}