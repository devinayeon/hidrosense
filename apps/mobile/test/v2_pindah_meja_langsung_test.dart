// Regresi: tombol "Lihat meja" di halaman sukses "Pindah ke meja" harus
// menggantikan halaman sukses langsung dengan Detail meja, tanpa kembali ke
// Detail semaian dulu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindah_meja_page.dart';

void main() {
  testWidgets('"Lihat meja" membuka Detail meja langsung dari halaman sukses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    V2SemaianPindah? hasil;
    String? mejaDibuka;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                hasil = await Navigator.of(context).push<V2SemaianPindah>(
                  MaterialPageRoute<V2SemaianPindah>(
                    builder: (_) => V2PindahMejaFormPage(
                      item: designSemaianRomaineSiapPindah,
                      jumlahAwal: 200,
                      daftarMeja: const [
                        V2SemaianMeja(
                          nama: 'Meja A2',
                          lubangKosong: 200,
                          tableId: '2',
                        ),
                      ],
                      onPindahkan: (_) async {},
                      onLihatMeja: (tableId) {
                        mejaDibuka = tableId;
                        Navigator.of(
                          context,
                        ).pushReplacement<void, V2PindahMejaAksi>(
                          MaterialPageRoute<void>(
                            builder: (_) => const Scaffold(
                              body: Center(child: Text('DETAIL MEJA')),
                            ),
                          ),
                          result: V2PindahMejaAksi.lihatMeja,
                        );
                      },
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

    await tester.tap(find.text('Pindahkan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pindahkan').last);
    await tester.pumpAndSettle();
    expect(find.text('Lihat meja'), findsOneWidget);

    await tester.tap(find.text('Lihat meja'));
    await tester.pumpAndSettle();

    expect(
      mejaDibuka,
      '2',
      reason: 'tombol "Lihat meja" tidak membuka Detail meja tujuan',
    );
    expect(find.text('DETAIL MEJA'), findsOneWidget);
    expect(
      find.text('Lihat meja'),
      findsNothing,
      reason: 'halaman sukses harus digantikan, bukan ditumpuk',
    );
    expect(hasil, isNotNull);
    expect(
      hasil!.aksi,
      V2PindahMejaAksi.selesai,
      reason: 'Detail semaian tetap harus disegarkan saat pengguna kembali',
    );
  });
}