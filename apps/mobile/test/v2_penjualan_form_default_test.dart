// Regresi K-26: form "Catat penjualan" alur nyata (store terisi) dulu sudah
// berisi contoh "Warung Sari", 60 kg, Rp40.000 dari frame galeri. Kalau petani
// menekan Simpan tanpa mengubah apa pun, penjualan contoh itu ikut tersimpan.
// Sekarang alur nyata mulai kosong dan wajib memilih panen; pratinjau galeri
// tetap memakai isian contoh supaya frame 8.7 cocok.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_store.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_form_page.dart';

class _RecordingStore implements V2PenjualanStore {
  final List<V2PenjualanDraft> created = [];

  @override
  Future<V2Penjualan> create(V2PenjualanDraft draft) async {
    created.add(draft);
    return V2Penjualan(
      id: 'sale-1',
      pembeli: draft.pembeli,
      tanggal: draft.tanggal,
      jumlahKg: draft.jumlahKg,
      hargaPerKg: draft.hargaPerKg,
      pembayaran: draft.pembayaran,
      panen: 'Panen',
      panenAsal: 'Dari panen',
      panenId: draft.panenId,
    );
  }

  @override
  Future<V2PenjualanSnapshot> load() =>
      throw UnsupportedError('Tidak dipakai di form.');

  @override
  Future<V2Penjualan> markPaid(V2Penjualan existing) =>
      throw UnsupportedError('Tidak dipakai di form.');

  @override
  Future<V2Penjualan> reload(V2Penjualan existing) =>
      throw UnsupportedError('Tidak dipakai di form.');

  @override
  Future<V2Penjualan> update(V2Penjualan existing, V2PenjualanDraft draft) =>
      throw UnsupportedError('Tidak dipakai di form.');
}

final _panen = [
  V2PenjualanPanen(
    id: 'panen-1',
    tanggalPanen: DateTime(2026, 11, 6),
    sisaKg: 150,
  ),
];

String _textAt(WidgetTester tester, int index) =>
    tester.widget<TextField>(find.byType(TextField).at(index)).controller!.text;

void main() {
  testWidgets('alur nyata catat penjualan mulai kosong dan tidak prefill (K-26)', (
    tester,
  ) async {
    final store = _RecordingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: V2PenjualanFormPage(store: store, panen: _panen),
      ),
    );

    expect(_textAt(tester, 0), '');
    expect(_textAt(tester, 1), '');
    expect(_textAt(tester, 2), '');

    await tester.tap(find.text('Simpan'));
    await tester.pump();

    // Tanpa memilih panen dan tanpa mengisi apa pun, simpan ditolak.
    expect(find.text('Isi nama pembeli'), findsOneWidget);
    expect(find.text('Pilih panen'), findsOneWidget);
    expect(find.text('Isi jumlah'), findsOneWidget);
    expect(find.text('Isi harga'), findsOneWidget);
    expect(store.created, isEmpty);
  });

  testWidgets('pratinjau galeri tetap memakai isian contoh (frame 8.7)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2PenjualanFormPage.create()),
    );

    expect(_textAt(tester, 0), 'Warung Sari');
    expect(_textAt(tester, 1), '60');
    expect(_textAt(tester, 2), '40.000');
  });
}
