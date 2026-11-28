import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_models.dart';
import 'package:hidrosense_mobile/features/pest/presentation/pages/rotation_history_page.dart';
import 'package:hidrosense_mobile/features/pest/presentation/viewmodels/pest_providers.dart';
import 'package:hidrosense_mobile/features/pest/presentation/widgets/decision_sheets.dart';
import 'package:hidrosense_mobile/features/pest/presentation/widgets/recommendation_card.dart';

import 'pest_repository_test.dart' show recJson;
import 'pest_viewmodels_test.dart' show FakeRepo;

PestRecommendation rec({
  String id = '1',
  String status = 'menunggu',
  Map<String, dynamic> extra = const {},
  Map<String, dynamic>? obat,
}) {
  final base = recJson(id: id, status: status, extra: extra);
  if (obat != null) {
    base['obat'] = {...(base['obat'] as Map<String, dynamic>), ...obat};
  }
  return PestRecommendation.fromJson(base);
}

Widget host(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('RecommendationCard', () {
    testWidgets(
      'menunggu: obat, MoA, alasan, PHI "cek label", peringatan belum diverifikasi, dua tombol',
      (tester) async {
        await tester.pumpWidget(
          host(
            RecommendationCard(
              recommendation: rec(),
              onAccept: () async => null,
              onReject: () async => null,
            ),
          ),
        );
        expect(find.text('Spinosad'), findsOneWidget);
        expect(find.textContaining('MoA 5'), findsOneWidget);
        expect(find.text('Serangan sedang.'), findsOneWidget);
        expect(
          find.text('Masa tunggu panen: cek label produk.'),
          findsOneWidget,
        );
        expect(find.textContaining('belum diverifikasi pakar'), findsOneWidget);
        expect(find.text('Menunggu'), findsOneWidget);
        expect(find.text('Terima'), findsOneWidget);
        expect(find.text('Tolak'), findsOneWidget);
      },
    );

    testWidgets(
      'rencana rotasi, catatan NFT, dan peringatan izin selada tampil; muat di layar sempit huruf besar',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 1400),
              textScaler: TextScaler.linear(1.5),
            ),
            child: host(
              RecommendationCard(
                recommendation: rec(
                  obat: {
                    'status_registrasi': 'tidak_ditemukan',
                    'bahan_aktif': 'Asetamiprid',
                    'kode_moa': '4A',
                  },
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
                          'bahan_aktif': 'Perangkap lengket kuning',
                          'kode_moa': null,
                          'sisa_jatah': null,
                        },
                      ],
                    },
                  },
                ),
                onAccept: () async => null,
                onReject: () async => null,
              ),
            ),
          ),
        );
        expect(find.text('Urutan rotasi'), findsOneWidget);
        expect(find.text('MoA 4A · sisa 2x'), findsOneWidget);
        expect(find.text('Tanpa batas semprot'), findsOneWidget);
        expect(find.text('Maks. 2x per 30 hari.'), findsOneWidget);
        expect(find.text('Semprot daun, jangan ke nutrisi.'), findsOneWidget);
        expect(
          find.textContaining('Izin untuk selada tidak ditemukan.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PHI yang diketahui ditampilkan; obat terverifikasi tanpa peringatan',
      (tester) async {
        await tester.pumpWidget(
          host(
            RecommendationCard(
              recommendation: rec(
                obat: {
                  'phi_hari': 7,
                  'phi_sumber': 'Label AS untuk selada',
                  'terverifikasi': true,
                },
              ),
            ),
          ),
        );
        expect(find.text('Masa tunggu panen minimal 7 hari.'), findsOneWidget);
        expect(
          find.text(
            'Label AS untuk selada. Ikuti label produk Anda bila berbeda.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('belum diverifikasi'), findsNothing);
        expect(
          find.text('Terima'),
          findsNothing,
          reason: 'tanpa aksi, tidak ada tombol',
        );
      },
    );

    testWidgets('cara nonkimia: tanpa baris masa tunggu', (tester) async {
      await tester.pumpWidget(
        host(
          RecommendationCard(
            recommendation: rec(
              obat: {
                'jenis': 'mekanis',
                'kode_moa': null,
                'nama_moa': null,
                'bahan_aktif': 'Perangkap lengket biru',
              },
            ),
          ),
        ),
      );
      expect(find.textContaining('Masa tunggu'), findsNothing);
      expect(find.text('Tanpa kelompok MoA'), findsOneWidget);
    });

    testWidgets('diterima: tanggal pakai dan catatan, tanpa tombol', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          RecommendationCard(
            recommendation: rec(
              status: 'diterima',
              extra: {
                'tanggal_aplikasi': '2026-09-30',
                'tanggal_keputusan': '2026-09-30T01:00:00.000Z',
                'catatan_perawatan': 'Sore hari',
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
            onAccept: () async => null,
            onReject: () async => null,
          ),
        ),
      );
      expect(find.text('Dipakai 30 Sep 2026'), findsOneWidget);
      expect(find.text('Sore hari'), findsOneWidget);
      expect(find.text('Stok terpakai: Spinosad 25 SC 10 ml'), findsOneWidget);
      expect(find.text('Terima'), findsNothing);
    });

    testWidgets('ditolak: alasan terstruktur dan catatan tampil', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          RecommendationCard(
            recommendation: rec(
              status: 'ditolak',
              extra: {
                'alasan_penolakan': 'lainnya',
                'catatan_penolakan': 'Sudah dilepas predator',
                'tanggal_keputusan': '2026-09-30T01:00:00.000Z',
              },
            ),
          ),
        ),
      );
      expect(find.text('Alasan: Alasan lain'), findsOneWidget);
      expect(find.text('Sudah dilepas predator'), findsOneWidget);
    });

    testWidgets(
      'ketuk Terima dua kali cepat: aksi berjalan sekali; galat tampil sebagai snackbar',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecommendationCard(
                recommendation: rec(),
                onAccept: () async {
                  calls++;
                  await Future<void>.delayed(const Duration(milliseconds: 50));
                  return 'Server sibuk.';
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Terima'));
        await tester.pump();
        await tester.tap(find.text('Terima'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 80));
        expect(calls, 1);
        expect(find.text('Server sibuk.'), findsOneWidget);
      },
    );
  });

  group('lembar penolakan', () {
    Future<void> open(
      WidgetTester tester,
      void Function(({RejectReason? reason, String? note})?) onResult,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => onResult(await showRejectSheet(context)),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
    }

    bool submitEnabled(WidgetTester tester) {
      final button = find.ancestor(
        of: find.text('Tolak saran'),
        matching: find.byType(InkWell),
      );
      return button.evaluate().isNotEmpty &&
          tester.widget<InkWell>(button.first).onTap != null;
    }

    testWidgets('"lainnya" wajib catatan', (tester) async {
      ({RejectReason? reason, String? note})? result;
      await open(tester, (v) => result = v);
      expect(find.text('Alasan menolak (opsional)'), findsOneWidget);
      await tester.tap(find.text('Alasan lain'));
      await tester.pump();
      expect(submitEnabled(tester), isFalse, reason: '"lainnya" tanpa catatan');
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(submitEnabled(tester), isFalse, reason: 'catatan hanya spasi');
      await tester.enterText(find.byType(TextField), 'Sudah dilepas predator');
      await tester.pump();
      expect(submitEnabled(tester), isTrue);
      await tester.tap(find.text('Tolak saran'));
      await tester.pumpAndSettle();
      expect(result?.reason, RejectReason.lainnya);
      expect(result?.note, 'Sudah dilepas predator');
    });

    testWidgets('boleh menolak tanpa alasan; pilihan bisa dibatalkan', (
      tester,
    ) async {
      ({RejectReason? reason, String? note})? result;
      await open(tester, (v) => result = v);
      expect(submitEnabled(tester), isTrue);
      await tester.tap(find.text('Harga terlalu mahal'));
      await tester.pump();
      await tester.tap(find.text('Harga terlalu mahal'));
      await tester.pump();
      await tester.tap(find.text('Tolak saran'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result?.reason, isNull);
      expect(result?.note, isNull);
      expect(rejectSummary(null, null), 'Saran ditolak tanpa alasan.');
      expect(rejectSummary(null, 'x'), 'Alasan "Alasan lain" akan dicatat.');
    });

    testWidgets(
      'alasan biasa cukup tanpa catatan; catatan kosong menjadi null',
      (tester) async {
        ({RejectReason? reason, String? note})? result;
        await open(tester, (v) => result = v);
        await tester.tap(find.text('Harga terlalu mahal'));
        await tester.pump();
        expect(submitEnabled(tester), isTrue);
        await tester.tap(find.text('Tolak saran'));
        await tester.pumpAndSettle();
        expect(result?.reason, RejectReason.harga);
        expect(result?.note, isNull);
      },
    );
  });

  test(
    'stok tertaut obat yang disarankan tampil paling atas, urutan lain tetap',
    () {
      // Diminta pengguna 2026-11-28: bahan yang dipotong harus obat yang disarankan.
      const stok = [
        StockOption(id: '1', name: 'AB Mix', unit: 'ml'),
        StockOption(id: '2', name: 'Imidakloprid', unit: 'ml', katalogId: '15'),
        StockOption(id: '3', name: 'Asetamiprid', unit: 'ml', katalogId: '16'),
        StockOption(id: '4', name: 'Pupuk daun', unit: 'ml'),
      ];
      expect(urutkanStok(stok, '16').map((o) => o.id), ['3', '1', '2', '4']);
      expect(urutkanStok(stok, '99').map((o) => o.id), ['1', '2', '3', '4']);
    },
  );

  group('lembar terima', () {
    const stock = [StockOption(id: '4', name: 'Spinosad 25 SC', unit: 'ml')];

    Future<void> open(
      WidgetTester tester,
      void Function(AcceptDecision?) onResult, {
      List<StockOption> options = stock,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => onResult(
                  await showAcceptSheet(context, rec(), stock: options),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
    }

    bool enabled(WidgetTester tester) {
      final button = find.ancestor(
        of: find.text('Terima'),
        matching: find.byType(InkWell),
      );
      return button.evaluate().isNotEmpty &&
          tester.widget<InkWell>(button.first).onTap != null;
    }

    testWidgets('tanpa stok dipilih: boleh langsung terima, tanpa bahan', (
      tester,
    ) async {
      AcceptDecision? result;
      await open(tester, (v) => result = v);
      expect(enabled(tester), isTrue);
      await tester.tap(find.text('Terima'));
      await tester.pumpAndSettle();
      expect(result?.material, isNull);
    });

    testWidgets('memilih stok mewajibkan jumlah sah; koma diterima', (
      tester,
    ) async {
      AcceptDecision? result;
      await open(tester, (v) => result = v);
      await tester.tap(find.text('Tidak memakai stok'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spinosad 25 SC (ml)').last);
      await tester.pumpAndSettle();
      expect(enabled(tester), isFalse, reason: 'jumlah masih kosong');
      await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah (ml)'),
        '0',
      );
      await tester.pump();
      expect(enabled(tester), isFalse);
      expect(find.textContaining('lebih dari 0'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah (ml)'),
        '2,5',
      );
      await tester.pump();
      expect(enabled(tester), isTrue);
      await tester.tap(find.text('Terima'));
      await tester.pumpAndSettle();
      expect(result?.material?.amount, '2.5');
      expect(result?.material?.unit, 'ml');
    });

    testWidgets('tanpa akses stok: pilihan stok tidak tampil', (tester) async {
      await open(tester, (_) {}, options: const []);
      expect(find.text('Tidak memakai stok'), findsNothing);
    });
  });

  group('RotationHistoryPage', () {
    Widget page(FakeRepo repo) => ProviderScope(
      overrides: [pestRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: RotationHistoryPage()),
    );

    testWidgets('memuat daftar, menampilkan chip filter status dan hama', (
      tester,
    ) async {
      final repo = FakeRepo()
        ..listFn = (s, k, p) => RecommendationPage(
          items: [
            rec(id: '1'),
            rec(
              id: '2',
              status: 'ditolak',
              extra: {
                'alasan_penolakan': 'harga',
                'tanggal_keputusan': '2026-09-30T01:00:00.000Z',
              },
            ),
          ],
          page: 1,
          totalPages: 1,
        );
      await tester.pumpWidget(page(repo));
      await tester.pumpAndSettle();
      for (final label in [
        'Semua',
        'Menunggu',
        'Diterima',
        'Ditolak',
        'Semua hama',
        'Thrips',
        'Kutu kebul',
        'Kutu daun',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      // Daftar riwayat tampil tertutup: ringkasan 1–2 baris per entri (BUG-32).
      expect(find.textContaining('Spinosad'), findsNWidgets(2));
      expect(find.text('Lihat detail'), findsNWidgets(2));
      expect(find.text('Masa tunggu panen: cek label produk.'), findsNothing);

      // Membuka satu entri memunculkan rincian lengkapnya saja.
      await tester.tap(find.text('Lihat detail').first);
      await tester.pumpAndSettle();
      expect(find.text('Spinosad'), findsOneWidget);
      expect(find.text('Masa tunggu panen: cek label produk.'), findsOneWidget);
      expect(find.text('Sembunyikan detail'), findsOneWidget);

      // Menutup lagi menyembunyikan rincian (header tanggal menggeser kartu,
      // jadi pastikan tombolnya terlihat dulu).
      await tester.ensureVisible(find.text('Sembunyikan detail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sembunyikan detail'));
      await tester.pumpAndSettle();
      expect(find.text('Spinosad'), findsNothing);
    });

    testWidgets('mengetuk filter "Diterima" memuat ulang dengan status itu', (
      tester,
    ) async {
      final seen = <RecommendationStatus?>[];
      final repo = FakeRepo()
        ..listFn = (s, k, p) {
          seen.add(s);
          return RecommendationPage(items: const [], page: 1, totalPages: 1);
        };
      await tester.pumpWidget(page(repo));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(GestureDetector, 'Diterima').first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(seen, [null, RecommendationStatus.diterima]);
    });

    testWidgets(
      'kosong: pesan arah; galat: pesan dan tombol coba lagi yang memuat ulang',
      (tester) async {
        var fail = true;
        final repo = FakeRepo()
          ..listFn = (s, k, p) {
            if (fail) throw const ApiException(503, 'DOWN', 'Server sibuk.');
            return RecommendationPage(items: const [], page: 1, totalPages: 1);
          };
        await tester.pumpWidget(page(repo));
        await tester.pumpAndSettle();
        expect(find.text('Server sibuk.'), findsOneWidget);
        fail = false;
        await tester.tap(find.text('Coba lagi'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Belum ada rekomendasi'), findsOneWidget);
      },
    );
  });
}
