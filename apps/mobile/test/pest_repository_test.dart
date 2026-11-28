import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_models.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_repository.dart';
import 'package:hidrosense_mobile/features/pest/domain/pest_summary.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/damage_fixture.dart';

Map<String, dynamic> recJson({
  String id = '7',
  String status = 'menunggu',
  String hama = 'thrips',
  String meja = '1',
  Map<String, dynamic> extra = const {},
}) => {
  'id_rekomendasi': id,
  'id_meja': meja,
  'kode_meja': 'M-01',
  'id_hasil_deteksi': null,
  'hama': hama,
  'tingkat': 'sedang',
  'status': status,
  'obat': {
    'id_katalog': '10',
    'bahan_aktif': 'Spinosad',
    'jenis': 'kimia',
    'kode_moa': '5',
    'nama_moa': 'Modulator alosterik reseptor asetilkolin nikotinik (spinosin)',
    'catatan': null,
    'phi_hari': null,
    'phi_sumber': null,
    'sumber': 'https://ucanr.edu/node/109663',
    'terverifikasi': false,
  },
  'rule_id': 'ROT-MOA',
  'alasan': 'Serangan sedang.',
  'alasan_penolakan': null,
  'catatan_penolakan': null,
  'tanggal_aplikasi': null,
  'catatan_perawatan': null,
  'tanggal_rekomendasi': '2026-09-30T00:00:00.000Z',
  'tanggal_keputusan': null,
  'bahan_terpakai': const <Object>[],
  ...extra,
};

http.Response ok(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'rekomendasi: JSON server dipetakan, obat tanpa PHI tetap null (bukan 0)',
    () {
      final r = PestRecommendation.fromJson(recJson());
      expect(r.pest, PestKind.thrips);
      expect(r.severity, PestSeverity.sedang);
      expect(r.status, RecommendationStatus.menunggu);
      expect(r.medicine.preHarvestDays, isNull);
      expect(r.medicine.verified, isFalse);
      expect(r.medicine.kind, MedicineKind.kimia);
    },
  );

  test('rekomendasi: bentuk tidak valid ditolak keras', () {
    for (final bad in [
      recJson(hama: 'tikus'),
      recJson(status: 'selesai'),
      recJson(extra: {'tingkat': 'parah'}),
      recJson(extra: {'tanggal_rekomendasi': 'kemarin'}),
      recJson(extra: {'obat': 'Spinosad'}),
    ]) {
      expect(() => PestRecommendation.fromJson(bad), throwsFormatException);
    }
  });

  test(
    'buat rekomendasi mengirim kunci idempotensi dan body sesuai kontrak',
    () async {
      late http.Request seen;
      final api = apiFor((r) async {
        seen = r;
        return ok({'data': recJson(), 'replayed': false}, status: 201);
      });
      addTearDown(api.close);
      final repo = PestRepository(api);
      final rec = await repo.createRecommendation(
        tableId: '1',
        pest: PestKind.thrips,
        severity: PestSeverity.sedang,
        scanId: '3',
        idempotencyKey: 'key-1',
      );
      expect(seen.url.path, endsWith('/rekomendasi-obat'));
      expect(seen.headers['Idempotency-Key'], 'key-1');
      expect(jsonDecode(seen.body), {
        'id_meja': '1',
        'hama': 'thrips',
        'tingkat': 'sedang',
        'id_hasil_deteksi': '3',
      });
      expect(rec.id, '7');
    },
  );

  test('respons untuk meja atau hama lain ditolak', () async {
    final api = apiFor(
      (r) async => ok({'data': recJson(meja: '2')}, status: 201),
    );
    addTearDown(api.close);
    expect(
      PestRepository(api).createRecommendation(
        tableId: '1',
        pest: PestKind.thrips,
        severity: PestSeverity.sedang,
      ),
      throwsFormatException,
    );
  });

  test(
    'daftar: filter status/meja/hama dikirim, dan status tak sesuai ditolak',
    () async {
      late Uri url;
      final api = apiFor((r) async {
        url = r.url;
        return ok({
          'data': [
            recJson(
              status: 'diterima',
              extra: {
                'tanggal_aplikasi': '2026-09-30',
                'tanggal_keputusan': '2026-09-30T01:00:00.000Z',
              },
            ),
          ],
          'meta': {'page': 1, 'limit': 20, 'total': 1, 'total_pages': 1},
        });
      });
      addTearDown(api.close);
      final page = await PestRepository(api).list(
        status: RecommendationStatus.diterima,
        tableId: '1',
        pest: PestKind.thrips,
      );
      expect(url.queryParameters, {
        'page': '1',
        'limit': '20',
        'status': 'diterima',
        'id_meja': '1',
        'hama': 'thrips',
      });
      expect(page.items.single.appliedOn, '2026-09-30');
      expect(page.hasMore, isFalse);
      // Server yang mengabaikan filter tidak boleh membuat daftar "diterima" berisi yang lain.
      expect(
        PestRepository(api).list(status: RecommendationStatus.ditolak),
        throwsFormatException,
      );
    },
  );

  test(
    'terima: catatan kosong tidak dikirim; hasil harus berstatus diterima',
    () async {
      late http.Request seen;
      final api = apiFor((r) async {
        seen = r;
        return ok({
          'data': recJson(
            status: 'diterima',
            extra: {
              'tanggal_aplikasi': '2026-09-30',
              'tanggal_keputusan': '2026-09-30T01:00:00.000Z',
            },
          ),
        });
      });
      addTearDown(api.close);
      final repo = PestRepository(api);
      await repo.accept('7', note: '   ');
      expect(seen.url.path, endsWith('/rekomendasi-obat/7/terima'));
      expect(jsonDecode(seen.body), <String, dynamic>{});
      final stale = apiFor((r) async => ok({'data': recJson()}));
      addTearDown(stale.close);
      expect(
        PestRepository(stale).accept('7'),
        throwsFormatException,
        reason: 'masih menunggu = bukan hasil keputusan',
      );
    },
  );

  test(
    'terima dengan bahan: dikirim sebagai `bahan`, hasil memuat stok terpakai',
    () async {
      late http.Request seen;
      final api = apiFor((r) async {
        seen = r;
        return ok({
          'data': recJson(
            status: 'diterima',
            extra: {
              'tanggal_aplikasi': '2026-09-30',
              'tanggal_keputusan': '2026-09-30T01:00:00.000Z',
              'bahan_terpakai': [
                {
                  'id_inventaris': '4',
                  'nama_barang': 'Spinosad 25 SC',
                  'jumlah': '10',
                  'satuan': 'ml',
                },
              ],
            },
          ),
        });
      });
      addTearDown(api.close);
      final rec = await PestRepository(api).accept(
        '7',
        materials: const [
          StockLineDraft(inventoryId: '4', amount: '10', unit: 'ml'),
        ],
      );
      expect(jsonDecode(seen.body), {
        'bahan': [
          {'id_inventaris': '4', 'jumlah': '10', 'satuan': 'ml'},
        ],
      });
      expect(rec.materials.single.name, 'Spinosad 25 SC');
    },
  );

  test('normalizeQuantity mengikuti pola desimal backend', () {
    expect(normalizeQuantity('10'), '10');
    expect(normalizeQuantity(' 2,5 '), '2.5');
    expect(normalizeQuantity('0.25'), '0.25');
    for (final bad in [
      '',
      '0',
      '0.00',
      '-1',
      '1.234',
      'abc',
      '1e3',
      '12345678901',
    ]) {
      expect(normalizeQuantity(bad), isNull, reason: bad);
    }
  });

  test(
    'tolak: alasan terstruktur; "lainnya" tanpa catatan ditolak sebelum dikirim',
    () async {
      var calls = 0;
      late http.Request seen;
      final api = apiFor((r) async {
        calls++;
        seen = r;
        return ok({
          'data': recJson(
            status: 'ditolak',
            extra: {
              'alasan_penolakan': 'harga',
              'tanggal_keputusan': '2026-09-30T01:00:00.000Z',
            },
          ),
        });
      });
      addTearDown(api.close);
      final repo = PestRepository(api);
      expect(() => repo.reject('7', RejectReason.lainnya), throwsArgumentError);
      expect(
        () => repo.reject('7', RejectReason.lainnya, note: '  '),
        throwsArgumentError,
      );
      expect(calls, 0);
      final rec = await repo.reject('7', RejectReason.harga);
      expect(jsonDecode(seen.body), {'alasan': 'harga'});
      expect(rec.rejectionReason, RejectReason.harga);
    },
  );

  test('tolak tanpa alasan mengirim badan kosong', () async {
    late http.Request seen;
    final api = apiFor((r) async {
      seen = r;
      return ok({
        'data': recJson(
          status: 'ditolak',
          extra: {'tanggal_keputusan': '2026-09-30T01:00:00.000Z'},
        ),
      });
    });
    addTearDown(api.close);
    final rec = await PestRepository(api).reject('7', null);
    expect(jsonDecode(seen.body), isEmpty);
    expect(rec.rejectionReason, isNull);
  });

  test(
    'rencana rotasi dan status registrasi terbaca; saran lama tanpa keduanya tetap sah',
    () {
      final old = PestRecommendation.fromJson(recJson());
      expect(old.plan, isNull);
      expect(old.medicine.registration, RegistrationStatus.unchecked);

      final json = recJson(
        extra: {
          'rencana': {
            'jumlah_kombinasi': 4,
            'langkah': [
              {
                'urutan': 1,
                'bahan_aktif': 'Asetamiprid',
                'kode_moa': '4A',
                'sisa_jatah': 2,
              },
              {
                'urutan': 2,
                'bahan_aktif': 'Perangkap',
                'kode_moa': null,
                'sisa_jatah': null,
              },
            ],
          },
        },
      );
      (json['obat'] as Map<String, dynamic>)['status_registrasi'] =
          'tidak_ditemukan';
      final rec = PestRecommendation.fromJson(json);
      expect(rec.plan!.combinationCount, 4);
      expect(rec.plan!.steps.map((s) => s.remaining), [2, null]);
      expect(rec.medicine.registration, RegistrationStatus.notFound);
    },
  );

  test('kesalahan API (409) sampai ke pemanggil dengan kode aslinya', () async {
    final api = apiFor(
      (r) async => ok({
        'error': {
          'code': 'RECOMMENDATION_ALREADY_DECIDED',
          'message': 'Sudah diputuskan.',
        },
      }, status: 409),
    );
    addTearDown(api.close);
    await expectLater(
      PestRepository(api).accept('7'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'RECOMMENDATION_ALREADY_DECIDED',
        ),
      ),
    );
  });

  group('unggah Cloudinary', () {
    const sig = CloudinarySignature(
      cloudName: 'demo',
      apiKey: '123456',
      timestamp: 1700000000,
      folder: 'hidrosense/pindai/1',
      signature: 'abc',
      uploadUrl: 'https://api.cloudinary.com/v1_1/demo/image/upload',
    );

    test(
      'mengirim field bertanda tangan persis dan menerima alamat Cloudinary',
      () async {
        late http.BaseRequest seen;
        final upload = MockClient.streaming((request, body) async {
          seen = request;
          final bytes = await body.toBytes();
          final text = latin1.decode(bytes);
          for (final part in [
            'name="api_key"',
            '123456',
            'name="timestamp"',
            '1700000000',
            'name="folder"',
            'hidrosense/pindai/1',
            'name="signature"',
            'abc',
            'name="file"',
          ]) {
            expect(text, contains(part));
          }
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'secure_url':
                      'https://res.cloudinary.com/demo/image/upload/v1/hidrosense/pindai/1/a.jpg',
                  'public_id': 'hidrosense/pindai/1/a',
                }),
              ),
            ),
            200,
          );
        });
        final api = apiFor((r) async => ok({}));
        addTearDown(api.close);
        final photo = await PestRepository(
          api,
          uploadClient: upload,
        ).uploadPhoto(Uint8List.fromList([1, 2, 3]), sig);
        expect(seen.url.host, 'api.cloudinary.com');
        expect(photo.publicId, 'hidrosense/pindai/1/a');
      },
    );

    test('alamat unggah atau foto bukan Cloudinary ditolak', () async {
      final api = apiFor((r) async => ok({}));
      addTearDown(api.close);
      const evil = CloudinarySignature(
        cloudName: 'demo',
        apiKey: '1',
        timestamp: 1,
        folder: 'f',
        signature: 's',
        uploadUrl: 'https://evil.example/upload',
      );
      final repo = PestRepository(
        api,
        uploadClient: MockClient((r) async => http.Response('{}', 200)),
      );
      expect(repo.uploadPhoto(Uint8List(1), evil), throwsFormatException);
      final badUrl = MockClient.streaming((request, body) async {
        await body.drain<void>();
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'secure_url': 'https://evil.example/a.jpg',
                'public_id': 'x',
              }),
            ),
          ),
          200,
        );
      });
      expect(
        PestRepository(
          api,
          uploadClient: badUrl,
        ).uploadPhoto(Uint8List(1), sig),
        throwsFormatException,
      );
    });

    test('Cloudinary gagal: ApiException UPLOAD_FAILED', () async {
      final api = apiFor((r) async => ok({}));
      addTearDown(api.close);
      final failing = MockClient.streaming((request, body) async {
        await body.drain<void>();
        return http.StreamedResponse(Stream.value(utf8.encode('{}')), 401);
      });
      await expectLater(
        PestRepository(
          api,
          uploadClient: failing,
        ).uploadPhoto(Uint8List(1), sig),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'UPLOAD_FAILED'),
        ),
      );
    });
  });

  test('simpan pindaian: kunci idempotensi dan hitungan per hama', () async {
    late http.Request seen;
    final api = apiFor((r) async {
      seen = r;
      return ok({
        'data': {'id_hasil_deteksi': '9'},
      }, status: 201);
    });
    addTearDown(api.close);
    final id = await PestRepository(api).saveScan(
      transferId: '1',
      photo: const UploadedPhoto(
        secureUrl: 'https://res.cloudinary.com/demo/a.jpg',
        publicId: 'a',
      ),
      modelVersion: 'yolo11n-fp16-cd388bda',
      findings: const [
        ScanFindingDraft(
          pest: PestKind.aphids,
          count: 12,
          maxConfidence: 0.912345,
        ),
      ],
      idempotencyKey: 'scan-1',
    );
    expect(id, '9');
    expect(seen.headers['Idempotency-Key'], 'scan-1');
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['deteksi'], [
      {'hama': 'aphids', 'jumlah': 12, 'confidence_maks': 0.9123},
    ]);
    expect(body['id_pemindahan'], '1');
  });
}
