// Regresi BUG-22: tab Rawat tidak pernah menampilkan foto yang sudah dipindai,
// padahal backend menyimpan daftarnya di `GET /pindaian`. Uji ini menjaga tiga
// hal: model/kueri daftar pindaian, penggabungan status rekomendasi lewat
// `scanId`, dan tampilan baris “Pindaian terbaru” beserta akses riwayat rotasi.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_models.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_repository.dart';
import 'package:hidrosense_mobile/features/pest/domain/pest_summary.dart';
import 'package:hidrosense_mobile/features/pest/presentation/viewmodels/pest_providers.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_rawat_data.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_rawat_connected.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_list_page.dart';
import 'package:hidrosense_mobile/views/v2/theme/v2_tokens.dart';
import 'package:http/http.dart' as http;

import 'pest_repository_test.dart' show ok, recJson;
import 'support/damage_fixture.dart';

Map<String, dynamic> scanJson({
  String id = '3',
  String tableId = '1',
  String? hama = 'thrips',
  int jumlah = 3,
  double? confidence = 0.87,
  String tanggal = '2026-11-24T02:00:00.000Z',
}) => {
  'id_hasil_deteksi': id,
  'id_pemindahan': '1',
  'id_meja': tableId,
  'gambar': 'https://res.cloudinary.com/demo/image/upload/v1/hidrosense/pindai/1/a.jpg',
  'cloudinary_public_id': 'hidrosense/pindai/1/a',
  'versi_model': 'yolo-v1',
  'tanggal_deteksi': tanggal,
  'deteksi': [
    if (hama != null)
      {'hama': hama, 'jumlah': jumlah, 'confidence_maks': confidence},
  ],
};

http.Response scanReply(List<Object> rows, {int page = 1}) => ok({
  'data': rows,
  'meta': {'page': page, 'limit': 20, 'total': rows.length, 'total_pages': 1},
});

void main() {
  test('pindaian: JSON server dipetakan, foto tanpa hama tetap sah', () {
    final record = PestScanRecord.fromJson(scanJson());
    expect(record.id, '3');
    expect(record.tableId, '1');
    expect(record.detectedAt.isUtc, isTrue);
    expect(record.detections.single.pest, PestKind.thrips);
    expect(record.detections.single.count, 3);
    expect(record.detections.single.confidencePercent, 87);
    expect(PestScanRecord.fromJson(scanJson(hama: null)).adaHama, isFalse);
  });

  test('pindaian: bentuk tidak valid ditolak keras', () {
    for (final bad in [
      scanJson(tanggal: 'kemarin'),
      scanJson(hama: 'tikus'),
      {...scanJson(), 'deteksi': 'thrips'},
    ]) {
      expect(() => PestScanRecord.fromJson(bad), throwsFormatException);
    }
  });

  test('daftar pindaian memakai GET /pindaian dengan halaman dan batas', () async {
    late http.Request seen;
    final api = apiFor((r) async {
      seen = r;
      return scanReply([scanJson()]);
    });
    addTearDown(api.close);

    final page = await PestRepository(api).listScans(page: 2, limit: 5);
    expect(seen.method, 'GET');
    expect(seen.url.path, endsWith('/pindaian'));
    expect(seen.url.queryParameters['page'], '2');
    expect(seen.url.queryParameters['limit'], '5');
    expect(seen.url.queryParameters.containsKey('id_pemindahan'), isFalse);
    expect(page.items.single.id, '3');
    expect(page.hasMore, isFalse);
  });

  test('status rekomendasi digabung ke pindaian lewat scanId', () async {
    final api = apiFor((r) async {
      if (r.url.path.endsWith('/pindaian')) {
        return scanReply([
          scanJson(id: '3'),
          scanJson(id: '4', tanggal: '2026-11-23T02:00:00.000Z'),
        ]);
      }
      if (r.url.path.endsWith('/rekomendasi-obat')) {
        return ok({
          'data': [
            recJson(id: '7', status: 'diterima', extra: {'id_hasil_deteksi': '3'}),
          ],
          'meta': {'page': 1, 'total_pages': 1},
        });
      }
      throw StateError('alamat tak terduga: ${r.url}');
    });
    addTearDown(api.close);
    final container = ProviderContainer(
      overrides: [pestRepositoryProvider.overrideWithValue(PestRepository(api))],
    );
    addTearDown(container.dispose);

    final entries = await container.read(pestScansProvider.future);
    expect(entries, hasLength(2));
    expect(entries.first.scan.id, '3');
    expect(entries.first.status, RecommendationStatus.diterima);
    expect(entries.last.status, isNull);
  });

  test('invalidasi memuat ulang daftar pindaian', () async {
    var panggilan = 0;
    final api = apiFor((r) async {
      if (r.url.path.endsWith('/pindaian')) {
        panggilan++;
        return scanReply([scanJson()]);
      }
      return ok({
        'data': <Object>[],
        'meta': {'page': 1, 'total_pages': 1},
      });
    });
    addTearDown(api.close);
    final container = ProviderContainer(
      overrides: [pestRepositoryProvider.overrideWithValue(PestRepository(api))],
    );
    addTearDown(container.dispose);
    final langganan = container.listen(pestScansProvider, (_, _) {});
    addTearDown(langganan.close);

    await container.read(pestScansProvider.future);
    expect(panggilan, 1);

    // Inilah yang dipanggil tab Rawat setelah halaman pindai/riwayat ditutup.
    container.invalidate(pestScansProvider);
    await container.read(pestScansProvider.future);
    expect(panggilan, 2);
  });

  test('pindaian server dipetakan ke baris Rawat', () {
    final entry = ScanEntry(
      scan: PestScanRecord.fromJson(scanJson()),
      recommendations: [PestRecommendation.fromJson(recJson(status: 'menunggu'))],
    );
    final item = v2PindaiItemFromScan(entry, 'Meja A2');
    expect(item.hama, 'Thrips');
    expect(item.meja, 'Meja A2');
    expect(item.labelKicker, startsWith('Meja A2'));
    expect(item.keyakinan, 87);
    expect(item.status, V2PindaiStatus.menunggu);
    expect(item.rincian.single, contains('3 ekor'));
  });

  testWidgets('tab Rawat menampilkan pindaian dan membuka riwayat rotasi', (tester) async {
    var rotasiDibuka = 0;
    V2PindaiItem? dibuka;
    final item = V2PindaiItem(
      id: '3',
      hama: 'Thrips, Kutu kebul',
      meja: 'Meja A2',
      tanggal: DateTime(2026, 11, 24),
      keyakinan: 87,
      status: V2PindaiStatus.diterima,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light,
        home: Scaffold(
          body: V2RawatTabView(
            riwayat: const <V2RawatItem>[],
            pindaian: [item],
            showPindaian: true,
            onOpenRotasi: () => rotasiDibuka++,
            onTapPindai: (value) => dibuka = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pindaian terbaru'), findsOneWidget);
    expect(find.text('Thrips, Kutu kebul'), findsOneWidget);
    expect(find.text('87%'), findsOneWidget);
    expect(find.text('Diterima'), findsOneWidget);

    await tester.ensureVisible(find.text('Thrips, Kutu kebul'));
    await tester.tap(find.text('Thrips, Kutu kebul'));
    await tester.pumpAndSettle();
    expect(dibuka?.id, '3');

    await tester.ensureVisible(find.text('Riwayat rotasi'));
    await tester.tap(find.text('Riwayat rotasi'));
    await tester.pumpAndSettle();
    expect(rotasiDibuka, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab Rawat tanpa pindaian memberi petunjuk, bukan daftar kosong', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light,
        home: Scaffold(
          body: V2RawatTabView(
            riwayat: [designRawatSelesai12],
            showPindaian: true,
            onOpenRotasi: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada foto daun yang dipindai.'), findsOneWidget);
    expect(find.text('Riwayat perawatan'), findsOneWidget);
  });
}