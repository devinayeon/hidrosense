// Regresi batch perbaikan Panen (sesi ini):
// (1) kartu "Berat layak" tetap tampil saat form menampilkan galat;
// (2) pemilih tanaman hanya menawarkan batch siap panen (HST >= 45 atau
//     HSS >= 60); baris tanpa tanggal/HSS tetap tampil;
// (3) membuka pemilih benar-benar menyaring batch muda;
// (4) "Ubah panen" menampilkan spinner lebih dulu, lalu tetap terbuka saat
//     server gagal supaya isian tidak perlu diulang;
// (5) refresh panen menerbitkan daftar batch lebih dulu, tanpa menunggu
//     riwayat panen selesai.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/harvest_record.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_panen_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_edit_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_tanaman_sheet.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_button.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_dialog.dart';

import 'support/harvest_fixture.dart';

void main() {
  testWidgets('kartu "Berat layak" tetap tampil walau form bergalat', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2PanenFormPage.validation()),
    );

    expect(find.text('Pilih tanaman'), findsWidgets);
    expect(find.text('Isi berat total'), findsOneWidget);
    expect(find.text('Berat layak'), findsOneWidget);
  });

  test(
    'siap panen: HST >= 45 atau HSS >= 60, data tak diketahui tetap lolos',
    () {
      final hariIni = DateTime(2026, 11, 27);
      V2PanenEstimasi item({DateTime? pindah, int? hss}) => V2PanenEstimasi(
        meja: 'Meja',
        varietas: 'Romaine',
        jumlahTanaman: 10,
        hariLagi: 0,
        transferDate: pindah,
        hss: hss,
      );

      expect(
        v2TanamanSiapDipanen(
          item(pindah: DateTime(2026, 10, 13)), // HST 45
          hariIni: hariIni,
        ),
        isTrue,
      );
      expect(
        v2TanamanSiapDipanen(
          item(pindah: DateTime(2026, 10, 14)), // HST 44
          hariIni: hariIni,
        ),
        isFalse,
      );
      expect(v2TanamanSiapDipanen(item(hss: 60), hariIni: hariIni), isTrue);
      expect(v2TanamanSiapDipanen(item(hss: 59), hariIni: hariIni), isFalse);
      // Tanpa tanggal pindah dan tanpa HSS: kesiapan tak bisa dinilai.
      expect(v2TanamanSiapDipanen(item(), hariIni: hariIni), isTrue);
    },
  );

  testWidgets('pemilih tanaman hanya menampilkan batch siap panen', (
    tester,
  ) async {
    final hariIni = DateTime(2026, 11, 27);
    final pilihan = <V2PanenEstimasi>[
      V2PanenEstimasi(
        meja: 'Meja Siap',
        varietas: 'Romaine',
        jumlahTanaman: 240,
        hariLagi: 0,
        transferId: 'siap',
        transferDate: DateTime(2026, 10, 1), // HST 57
        hss: 65,
      ),
      V2PanenEstimasi(
        meja: 'Meja Muda',
        varietas: 'Butterhead',
        jumlahTanaman: 100,
        hariLagi: 25,
        transferId: 'muda',
        transferDate: DateTime(2026, 11, 20), // HST 7
        hss: 22,
      ),
      // Baris galeri tanpa tanggal/HSS: tetap terlihat.
      const V2PanenEstimasi(
        meja: 'Meja Galeri',
        varietas: 'Zukini',
        jumlahTanaman: 77,
        hariLagi: 2,
        transferId: 'galeri',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: V2PanenFormPage(pilihan: pilihan, initialDate: hariIni),
      ),
    );

    await tester.tap(find.text('Pilih tanaman'));
    await tester.pumpAndSettle();

    expect(find.text('Meja Siap, Romaine'), findsOneWidget);
    expect(find.text('Meja Galeri, Zukini'), findsOneWidget);
    expect(find.text('Meja Muda, Butterhead'), findsNothing);
  });

  testWidgets('pemilih tanaman menjelaskan saat belum ada yang siap', (
    tester,
  ) async {
    final pilihan = <V2PanenEstimasi>[
      V2PanenEstimasi(
        meja: 'Meja Muda',
        varietas: 'Butterhead',
        jumlahTanaman: 100,
        hariLagi: 25,
        transferId: 'muda',
        transferDate: DateTime(2026, 11, 20),
        hss: 22,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: V2PanenFormPage(
          pilihan: pilihan,
          initialDate: DateTime(2026, 11, 27),
        ),
      ),
    );

    await tester.tap(find.text('Pilih tanaman'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Belum ada tanaman yang siap dipanen'),
      findsOneWidget,
    );
  });

  testWidgets(
    'ubah panen: spinner dulu, form tetap terbuka saat galat server',
    (tester) async {
      final completer = Completer<V2PanenItem>();
      await tester.pumpWidget(
        MaterialApp(
          home: V2PanenEditPage(
            item: designPanenTerjual,
            onSubmit: (_) => completer.future,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(V2Button, 'Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Simpan perubahan panen?'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(V2Dialog),
          matching: find.text('Simpan'),
        ),
      );
      await tester.pump();
      // Simpan menampilkan loading dulu, belum kembali ke Detail panen.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Ubah panen'), findsOneWidget);

      completer.completeError(StateError('Koreksi panen gagal.'));
      await tester.pumpAndSettle();

      // Galat tampil sebagai pesan dan form tetap terbuka.
      expect(find.text('Ubah panen'), findsOneWidget);
      expect(find.textContaining('Koreksi panen gagal.'), findsOneWidget);
    },
  );

  test('refresh menerbitkan batch dulu tanpa menunggu riwayat panen', () async {
    final repo = await loadedRepo();
    final read = Completer<List<HarvestRecord>>();
    repo.onRead = () => read.future;
    final vm = harvestVm(repo);
    addTearDown(vm.dispose);

    final pending = vm.refresh();
    await Future<void>.delayed(Duration.zero);

    // Daftar pemindahan sudah tiba; riwayat panen masih menunggu.
    expect(vm.current.transfersLoaded, isTrue);
    expect(vm.current.transfers, isNotEmpty);
    expect(vm.current.recordsLoaded, isFalse);
    expect(vm.current.records, isEmpty);

    read.complete([HarvestRecord.fromJson(harvestJson())]);
    await pending;

    expect(vm.current.recordsLoaded, isTrue);
    expect(vm.current.records, hasLength(1));
  });
}
