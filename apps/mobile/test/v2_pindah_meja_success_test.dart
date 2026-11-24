// Regresi BUG-28: tombol di halaman sukses "Pindah ke meja" (5.18/5.22) mati —
// di alur nyata tidak ada penangan, jadi ditekan pun tidak terjadi apa-apa.
// Uji ini memastikan tiap tombol menutup halaman sukses dan mengembalikan
// aksi yang benar ke pemanggil.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindah_meja_page.dart';

/// Membuka [form] dari sebuah tombol, lalu menyimpan hasil pop-nya.
Future<void> _pumpHost(WidgetTester tester, Widget form, void Function(V2SemaianPindah?) simpan) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              simpan(
                await Navigator.of(context).push<V2SemaianPindah>(
                  MaterialPageRoute<V2SemaianPindah>(builder: (_) => form),
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
}

void main() {
  testWidgets('tombol "Lihat meja" menutup halaman sukses dan mengembalikan aksi', (
    tester,
  ) async {
    V2SemaianPindah? hasil;
    await _pumpHost(tester, V2PindahMejaFormPage.form(), (r) => hasil = r);

    // Halaman sukses muncul setelah "Pindahkan".
    await tester.tap(find.text('Pindahkan'));
    await tester.pumpAndSettle();
    expect(find.text('Lihat meja'), findsOneWidget);

    await tester.tap(find.text('Lihat meja'));
    await tester.pumpAndSettle();

    expect(hasil, isNotNull, reason: 'tombol "Lihat meja" tidak bereaksi');
    expect(hasil!.aksi, V2PindahMejaAksi.lihatMeja);
  });

  testWidgets('tombol "Ke daftar semaian" mengembalikan aksi ke daftar', (
    tester,
  ) async {
    V2SemaianPindah? hasil;
    await _pumpHost(tester, V2PindahMejaFormPage.form(), (r) => hasil = r);

    await tester.tap(find.text('Pindahkan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ke daftar semaian'));
    await tester.pumpAndSettle();

    expect(hasil, isNotNull, reason: 'tombol "Ke daftar semaian" tidak bereaksi');
    expect(hasil!.aksi, V2PindahMejaAksi.keDaftarSemaian);
  });

  testWidgets('tombol "Pindahkan sisa" membuka lagi form untuk sisa benih', (
    tester,
  ) async {
    V2SemaianPindah? hasil;
    // 120 dari 200 benih: sisa 80, jadi halaman sukses menawarkan "Pindahkan sisa".
    await _pumpHost(
      tester,
      V2PindahMejaFormPage(
        item: designSemaianRomaineSiapPindah,
        jumlahAwal: 120,
      ),
      (r) => hasil = r,
    );

    await tester.tap(find.text('Pindahkan'));
    await tester.pumpAndSettle();
    expect(find.text('Pindahkan sisa'), findsOneWidget);

    await tester.tap(find.text('Pindahkan sisa'));
    await tester.pumpAndSettle();

    // Form dibuka lagi untuk sisa benih; form pertama belum selesai.
    expect(find.text('Jumlah tanaman'), findsOneWidget);
    expect(find.text('Pindahkan'), findsOneWidget);
    expect(hasil, isNull);
  });
}
