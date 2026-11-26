// Regresi D-39 (keputusan PM 25–26 Nov 2026): penjualan punya "keterangan"
// bebas opsional. Sebelumnya model, form, dan alur simpan tidak mengenal
// kolom itu, sehingga catatan petani hilang walau server sudah menyediakannya
// (`sales/contracts.ts`). Uji ini memaku prefill, hasil simpan mode pratinjau,
// pengiriman ke store, tampilan di detail, dan pemetaan dari antrean.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/sync_queue_item.dart';
import 'package:hidrosense_mobile/viewmodels/v2_penjualan_mappers.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_store.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_form_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_select_field.dart';

final _panen = <V2PenjualanPanen>[
  V2PenjualanPanen(
    id: 'panen-6-nov',
    tanggalPanen: DateTime(2026, 11, 6),
    sisaKg: 150,
  ),
];

/// Indeks TextField form: 0 pembeli, 1 jumlah, 2 harga, 3 keterangan.
const _keterangan = 3;

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
      panen: 'Panen 6 Nov',
      panenAsal: 'Dari panen 6 Nov',
      keterangan: draft.keterangan,
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

Future<void> _pumpHost(
  WidgetTester tester,
  Widget form,
  void Function(V2Penjualan?) simpan,
) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              simpan(
                await Navigator.of(context).push<V2Penjualan>(
                  MaterialPageRoute<V2Penjualan>(builder: (_) => form),
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

String _textAt(WidgetTester tester, int index) =>
    tester.widget<TextField>(find.byType(TextField).at(index)).controller!.text;

void main() {
  testWidgets('form ubah memuat keterangan tersimpan', (tester) async {
    await _pumpHost(
      tester,
      V2PenjualanFormPage(
        initial: penjualanTokoSegar.copyWith(keterangan: 'Titip di warung'),
        panen: _panen,
      ),
      (_) {},
    );

    expect(_textAt(tester, _keterangan), 'Titip di warung');
  });

  testWidgets('simpan mempertahankan keterangan yang diubah', (tester) async {
    V2Penjualan? hasil;
    await _pumpHost(
      tester,
      V2PenjualanFormPage(
        initial: penjualanTokoSegar.copyWith(keterangan: 'Titip di warung'),
        panen: _panen,
      ),
      (r) => hasil = r,
    );

    await tester.enterText(
      find.byType(TextField).at(_keterangan),
      'Diambil besok pagi',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(hasil, isNotNull);
    expect(hasil!.keterangan, 'Diambil besok pagi');
  });

  testWidgets('keterangan kosong dikirim sebagai null', (tester) async {
    V2Penjualan? hasil;
    await _pumpHost(
      tester,
      V2PenjualanFormPage(
        initial: penjualanTokoSegar.copyWith(keterangan: 'Titip di warung'),
        panen: _panen,
      ),
      (r) => hasil = r,
    );

    await tester.enterText(find.byType(TextField).at(_keterangan), '   ');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(hasil, isNotNull);
    expect(hasil!.keterangan, isNull);
  });

  testWidgets('alur nyata mengirim keterangan ke store', (tester) async {
    final store = _RecordingStore();
    await _pumpHost(
      tester,
      V2PenjualanFormPage(store: store, panen: _panen),
      (_) {},
    );

    await tester.enterText(find.byType(TextField).at(0), 'Warung Sari');
    await tester.enterText(find.byType(TextField).at(1), '60');
    await tester.enterText(find.byType(TextField).at(2), '40.000');
    await tester.enterText(
      find.byType(TextField).at(_keterangan),
      'Bayar minggu depan',
    );
    // Pilih panen lewat sheet "Pilih panen".
    await tester.tap(find.byType(V2SelectField).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Panen 6 Nov'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    // Pop-up konfirmasi ulang (Sesi 9) muncul sebelum menulis ke store.
    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();

    expect(store.created, hasLength(1));
    expect(store.created.single.keterangan, 'Bayar minggu depan');
  });

  testWidgets('detail menampilkan baris keterangan bila ada', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: V2PenjualanDetailPage(
          penjualan: penjualanTokoSegar.copyWith(keterangan: 'Titip di warung'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keterangan'), findsOneWidget);
    expect(find.text('Titip di warung'), findsOneWidget);
  });

  testWidgets('detail tanpa keterangan tidak menampilkan barisnya', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: V2PenjualanDetailPage.tokoSegar(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keterangan'), findsNothing);
  });

  test('baris antrean membawa keterangan dari payload', () {
    final item = SyncQueueItem(
      key: 'k-jual-1',
      jenis: SyncQueueJenis.penjualan,
      subtitle: 'Catat penjualan',
      mode: SyncQueueMode.baru,
      target: 'create',
      payload:
          '{"tanggal_penjualan":"2026-11-12","pembeli":"Toko Segar",'
          '"status_pembayaran":"belum_lunas","keterangan":"Titip di warung",'
          '"id_panen":"panen-6-nov","jumlah_kg":"60.00",'
          '"harga_per_kg":"40000.00"}',
      createdAt: DateTime.utc(2026, 11, 12),
    );

    final penjualan = v2PenjualanFromQueue(item, const []);
    expect(penjualan, isNotNull);
    expect(penjualan!.keterangan, 'Titip di warung');
  });
}
