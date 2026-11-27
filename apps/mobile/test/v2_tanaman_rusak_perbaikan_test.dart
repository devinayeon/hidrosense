// Regresi sesi 10 lanjutan 3: alur "Detail tanaman" dan "Tanaman rusak".
//
// Permintaan client saat uji manual di HP:
// 1. "Catat rusak" tidak lagi ada di Detail tanaman; pencatatan hanya dari
//    halaman Tanaman rusak.
// 2. Laporan baru tetap tampil saat daftar rusak dibuka lagi tanpa keluar ke
//    daftar meja (BUG-73).
// 3. Ketukan baris membuka Detail kerusakan lebih dulu; tombol "Ubah
//    kerusakan" di dalamnya yang membuka form ubah.
// 4. Jenis "Busuk akar" berganti nama menjadi "Penyakit".
//
// Di kode lama: tombol "Catat rusak" ada di footer Detail tanaman, baris rusak
// langsung membuka form ubah, laporan baru hilang saat daftar dibuka ulang, dan
// chip menulis "Busuk akar".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_detail_tanaman_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_tanaman_rusak_page.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(420, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

/// Meja dengan satu batch Romaine dan belum ada laporan rusak.
V2MejaItem _mejaTanpaRusak() {
  const transferId = 't1';
  final tanaman = V2TanamanItem(
    varietas: 'Romaine',
    tanggalTanam: DateTime(2026, 11, 7),
    tanggalPanen: DateTime(2026, 12, 22),
    tanggalPindah: DateTime(2026, 11, 7),
    jumlahAktif: 40,
    jumlahAwal: 42,
    transferId: transferId,
    hariIni: DateTime(2026, 11, 15),
  );
  return V2MejaItem(
    id: 'm1',
    kode: 'A2',
    jumlahLubang: 240,
    terisi: 40,
    status: V2MejaStatus.tersedia,
    tanaman: <V2TanamanItem>[tanaman],
  );
}

void main() {
  testWidgets('Detail tanaman tidak lagi punya tombol Catat rusak', (
    tester,
  ) async {
    await _pump(tester, V2DetailTanamanPage.biasa());

    expect(find.text('Catat rusak'), findsNothing);
    expect(find.text('Ubah'), findsOneWidget);
  });

  testWidgets('baris rusak membuka Detail kerusakan, bukan form ubah', (
    tester,
  ) async {
    await _pump(tester, V2TanamanRusakPage.biasa());

    await tester.tap(find.text('2 tanaman, penyakit'));
    await tester.pumpAndSettle();

    expect(find.text('Detail kerusakan'), findsOneWidget);
    expect(find.text('Ubah kerusakan'), findsOneWidget);
    // Form ubah memakai tombol "Simpan"; halaman detail tidak.
    expect(find.text('Simpan'), findsNothing);
  });

  testWidgets('tombol Ubah kerusakan di detail membuka form ubah', (
    tester,
  ) async {
    await _pump(tester, V2TanamanRusakPage.biasa());

    await tester.tap(find.text('2 tanaman, penyakit'));
    await tester.pumpAndSettle();
    expect(find.text('Detail kerusakan'), findsOneWidget);

    await tester.tap(find.text('Ubah kerusakan'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan'), findsOneWidget);
    expect(find.text('Tanggal kejadian'), findsOneWidget);
  });

  testWidgets('ubah dari detail memperbarui baris di daftar rusak', (
    tester,
  ) async {
    await _pump(tester, V2TanamanRusakPage.biasa());

    await tester.tap(find.text('2 tanaman, penyakit'));
    await tester.pumpAndSettle();
    expect(find.text('Detail kerusakan'), findsOneWidget);

    await tester.tap(find.text('Ubah kerusakan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Layu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Kembali dari Detail kerusakan ke daftar.
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    expect(find.text('2 tanaman, layu'), findsOneWidget);
    expect(find.text('2 tanaman, penyakit'), findsNothing);
  });

  testWidgets('chip jenis memakai Penyakit, bukan Busuk akar', (tester) async {
    await _pump(tester, V2CatatRusakPage.catat());

    expect(find.text('Penyakit'), findsOneWidget);
    expect(find.text('Busuk akar'), findsNothing);
  });

  testWidgets('laporan baru tetap tampil saat daftar rusak dibuka lagi', (
    tester,
  ) async {
    final meja = _mejaTanpaRusak();
    await _pump(
      tester,
      V2DetailTanamanPage(
        tanaman: meja.tanaman.first,
        meja: meja,
        onCatatRusak: (draft) async => draft,
      ),
    );

    // Buka daftar rusak, catat satu laporan baru.
    await tester.tap(find.text('Tanaman rusak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catat rusak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Catat')),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 tanaman, penyakit'), findsOneWidget);

    // Keluar ke Detail tanaman, lalu buka daftar rusak lagi.
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('2 tanaman. Lihat daftar'), findsOneWidget);

    await tester.tap(find.text('Tanaman rusak'));
    await tester.pumpAndSettle();

    // Di kode lama baris ini hilang sampai pengguna keluar ke daftar meja.
    expect(find.text('2 tanaman, penyakit'), findsOneWidget);
  });
}
