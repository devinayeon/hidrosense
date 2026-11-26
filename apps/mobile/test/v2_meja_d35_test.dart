// Regresi D-35 (keputusan PM 25–26 Nov 2026): sebelum menyimpan perubahan,
// aplikasi menampilkan pop-up konfirmasi. Uji ini memaku bahwa form "Ubah
// meja" tidak langsung menutup/mengirim saat Simpan ditekan, tetapi menunggu
// jawaban dialog; form "Tambah meja" tidak memakai konfirmasi karena tidak
// mengubah data yang ada (K-18).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_form_page.dart';

/// Membuka form lewat tombol dan menyimpan hasil pop-nya.
Future<void> _pumpHost(
  WidgetTester tester,
  Widget form, {
  required void Function(V2MejaItem?) simpan,
}) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              simpan(
                await Navigator.of(context).push<V2MejaItem>(
                  MaterialPageRoute<V2MejaItem>(builder: (_) => form),
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
  testWidgets('Ubah meja: Simpan menampilkan pop-up konfirmasi lebih dulu', (
    tester,
  ) async {
    V2MejaItem? hasil;
    await _pumpHost(
      tester,
      V2MejaFormPage(meja: designMejaA2),
      simpan: (r) => hasil = r,
    );

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan perubahan meja?'), findsOneWidget);
    expect(hasil, isNull, reason: 'form belum boleh tertutup sebelum dikonfirmasi');
    // Isian tetap utuh di belakang dialog.
    expect(find.text('Ubah meja'), findsOneWidget);
  });

  testWidgets('Ubah meja: Batal membatalkan tanpa menutup form', (tester) async {
    V2MejaItem? hasil;
    await _pumpHost(
      tester,
      V2MejaFormPage(meja: designMejaA2),
      simpan: (r) => hasil = r,
    );

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan perubahan meja?'), findsNothing);
    expect(hasil, isNull);
    expect(find.text('Ubah meja'), findsOneWidget);
  });

  testWidgets('Ubah meja: konfirmasi menyimpan dan menutup form', (tester) async {
    V2MejaItem? hasil;
    await _pumpHost(
      tester,
      V2MejaFormPage(meja: designMejaA2),
      simpan: (r) => hasil = r,
    );

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    // Dua "Simpan": tombol form dan tombol utama dialog; ambil yang dialog.
    await tester.tap(find.text('Simpan').last);
    await tester.pumpAndSettle();

    expect(hasil, isNotNull);
    expect(hasil!.kode, 'A2');
    expect(hasil!.keterangan, 'Dekat pintu');
  });

  testWidgets('Tambah meja: Simpan tanpa pop-up konfirmasi', (tester) async {
    V2MejaItem? hasil;
    await _pumpHost(
      tester,
      const V2MejaFormPage.create(),
      simpan: (r) => hasil = r,
    );

    await tester.enterText(find.byType(TextField).at(0), 'B9');
    await tester.enterText(find.byType(TextField).at(1), '240');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan perubahan meja?'), findsNothing);
    expect(hasil, isNotNull);
    expect(hasil!.kode, 'B9');
  });
}
