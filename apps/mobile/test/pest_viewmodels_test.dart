import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_detector.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_models.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_repository.dart';
import 'package:hidrosense_mobile/features/pest/domain/pest_summary.dart';
import 'package:hidrosense_mobile/features/pest/domain/yolo_decoder.dart';
import 'package:hidrosense_mobile/features/pest/presentation/viewmodels/pest_history_viewmodel.dart';
import 'package:hidrosense_mobile/features/pest/presentation/viewmodels/pest_scan_viewmodel.dart';
import 'package:hidrosense_mobile/features/pest/presentation/viewmodels/recommendation_decider.dart';

import 'pest_repository_test.dart' show recJson;
import 'support/damage_fixture.dart';

class FakeRepo extends PestRepository {
  FakeRepo() : super(apiFor((r) async => throw StateError('jaringan tidak boleh dipakai')));

  int uploads = 0;
  int scans = 0;
  final List<(PestKind, PestSeverity, String?)> created = [];
  Object? failCreateFor;
  Completer<RecommendationPage>? gate;
  RecommendationPage Function(RecommendationStatus?, PestKind?, int)? listFn;
  int decisionCalls = 0;
  Completer<void>? decisionGate;

  @override
  Future<CloudinarySignature> signUpload() async => const CloudinarySignature(
    cloudName: 'demo', apiKey: '1', timestamp: 1, folder: 'f', signature: 's', uploadUrl: 'https://api.cloudinary.com/v1_1/demo/image/upload',
  );

  @override
  Future<UploadedPhoto> uploadPhoto(Uint8List bytes, CloudinarySignature sig, {String filename = 'pindai.jpg'}) async {
    uploads++;
    return const UploadedPhoto(secureUrl: 'https://res.cloudinary.com/demo/a.jpg', publicId: 'a');
  }

  @override
  Future<String> saveScan({
    required String transferId,
    required UploadedPhoto photo,
    required String modelVersion,
    required List<ScanFindingDraft> findings,
    String? idempotencyKey,
  }) async {
    scans++;
    return '9';
  }

  @override
  Future<PestRecommendation> createRecommendation({
    required String tableId,
    required PestKind pest,
    required PestSeverity severity,
    String? scanId,
    String? idempotencyKey,
  }) async {
    if (failCreateFor == pest) throw const ApiException(503, 'DOWN', 'Server sibuk.');
    created.add((pest, severity, idempotencyKey));
    return PestRecommendation.fromJson(recJson(id: '${created.length}', hama: pest.apiCode));
  }

  String? lastTableFilter;

  @override
  Future<RecommendationPage> list({
    RecommendationStatus? status,
    String? tableId,
    PestKind? pest,
    int page = 1,
    int limit = 20,
  }) async {
    lastTableFilter = tableId;
    if (gate != null) return gate!.future;
    return listFn!(status, pest, page);
  }

  final List<String?> decisionKeys = [];

  @override
  Future<PestRecommendation> accept(String id, {String? appliedOn, String? note, List<StockLineDraft> materials = const [], String? idempotencyKey}) async {
    decisionCalls++;
    decisionKeys.add(idempotencyKey);
    await decisionGate?.future;
    return PestRecommendation.fromJson(recJson(id: id, status: 'diterima', extra: {'tanggal_aplikasi': '2026-09-30', 'tanggal_keputusan': '2026-09-30T00:00:00.000Z'}));
  }

  @override
  Future<PestRecommendation> reject(String id, RejectReason? reason, {String? note, String? idempotencyKey}) async {
    decisionCalls++;
    decisionKeys.add(idempotencyKey);
    return PestRecommendation.fromJson(recJson(id: id, status: 'ditolak', extra: {'alasan_penolakan': reason?.apiCode, 'tanggal_keputusan': '2026-09-30T00:00:00.000Z'}));
  }
}

YoloDetection det(int cls, [double conf = 0.9]) =>
    YoloDetection(classId: cls, confidence: conf, x1: 0.1, y1: 0.1, x2: 0.2, y2: 0.2);

PestScanResult resultWith(List<YoloDetection> dets) => PestScanResult(
  findings: summarizeDetections(dets),
  detections: dets,
  modelVersion: 'yolo11n-fp16-cd388bda',
);

PestRecommendation rec(String id, RecommendationStatus s) => PestRecommendation.fromJson(
  recJson(id: id, status: s.apiCode, extra: s == RecommendationStatus.menunggu ? {} : {'tanggal_keputusan': '2026-09-30T00:00:00.000Z', if (s == RecommendationStatus.diterima) 'tanggal_aplikasi': '2026-09-30', if (s == RecommendationStatus.ditolak) 'alasan_penolakan': 'harga'}),
);

void main() {
  final photo = Uint8List.fromList([1, 2, 3]);

  group('PestScanNotifier', () {
    PestScanNotifier make(
      FakeRepo repo,
      Future<PestScanResult> Function(Uint8List) detect, {
      Future<String?> Function(String)? resolve,
    }) => PestScanNotifier(detect, repo, resolve ?? (t) async => 'batch-$t', RecommendationDecider(repo));

    test('analisis berhasil: tingkat awal dari heuristik, tanpa menyentuh jaringan', () async {
      final repo = FakeRepo();
      final n = make(repo, (_) async => resultWith([for (var i = 0; i < 3; i++) det(0), det(1)]));
      await n.analyze(photo);
      expect(n.state.phase, ScanPhase.analyzed);
      expect(n.state.severities[PestKind.whitefly], PestSeverity.sedang, reason: '3 whitefly >= P75 (2)');
      expect(n.state.severities[PestKind.aphids], PestSeverity.ringan);
      expect(repo.uploads + repo.scans + repo.created.length, 0);
    });

    test('foto rusak: gagal saat analisis, tanpa tombol simpan ulang', () async {
      final n = make(FakeRepo(), (_) async => throw const FormatException('Berkas bukan foto yang bisa dibaca.'));
      await n.analyze(photo);
      expect(n.state.phase, ScanPhase.failed);
      expect(n.state.canRetrySave, isFalse);
      expect(n.state.error, contains('bukan foto'));
    });

    test('simpan: unggah, pindaian, lalu satu rekomendasi per hama dengan tingkat pilihan pengguna', () async {
      final repo = FakeRepo();
      final n = make(repo, (_) async => resultWith([det(0), det(1)]));
      await n.analyze(photo);
      n.setSeverity(PestKind.aphids, PestSeverity.berat);
      await n.save(tableId: '1');
      expect(n.state.phase, ScanPhase.saved);
      expect((repo.uploads, repo.scans), (1, 1));
      expect(repo.created.map((c) => (c.$1, c.$2)), [(PestKind.whitefly, PestSeverity.ringan), (PestKind.aphids, PestSeverity.berat)]);
      expect(n.state.recommendations, hasLength(2));
    });

    test('meja tanpa tanaman aktif: tidak ada yang dikirim, pengguna boleh ganti meja', () async {
      final repo = FakeRepo();
      final n = make(repo, (_) async => resultWith([det(0)]), resolve: (t) async => t == '1' ? null : 'batch-$t');
      await n.analyze(photo);
      await n.save(tableId: '1');
      expect(n.state.phase, ScanPhase.analyzed);
      expect(n.state.error, contains('belum punya tanaman aktif'));
      expect(n.state.saveStarted, isFalse);
      expect(repo.uploads, 0);
      await n.save(tableId: '2');
      expect(n.state.phase, ScanPhase.saved);
      expect(n.state.tableId, '2');
    });

    test('gagal di tengah lalu diulang: tidak unggah ulang, tidak dobel, kunci sama', () async {
      final repo = FakeRepo()..failCreateFor = PestKind.aphids;
      final n = make(repo, (_) async => resultWith([det(0), det(1)]));
      await n.analyze(photo);
      await n.save(tableId: '1');
      expect(n.state.phase, ScanPhase.failed);
      expect(n.state.canRetrySave, isTrue);
      expect(n.state.error, 'Server sibuk.');
      expect(n.state.recommendations.map((r) => r.pest), [PestKind.whitefly], reason: 'yang sudah jadi tetap tampil');
      repo.failCreateFor = null;
      await n.save(tableId: '1');
      expect(n.state.phase, ScanPhase.saved);
      expect((repo.uploads, repo.scans), (1, 1), reason: 'foto dan pindaian tidak diulang');
      expect(repo.created.map((c) => c.$1), [PestKind.whitefly, PestKind.aphids]);
    });

    test('setelah simpan dimulai: tingkat dan meja terkunci, ulangan memakai isi yang sama', () async {
      // Respons yang hilang + isi berbeda dengan kunci sama = 409 OPERATION_CONFLICT selamanya.
      final repo = FakeRepo()..failCreateFor = PestKind.aphids;
      final n = make(repo, (_) async => resultWith([det(1)]));
      await n.analyze(photo);
      await n.save(tableId: '1');
      expect(n.state.canEditSeverity, isFalse);
      n.setSeverity(PestKind.aphids, PestSeverity.berat);
      expect(n.state.severities[PestKind.aphids], PestSeverity.ringan);
      repo.failCreateFor = null;
      await n.save(tableId: '9');
      expect(n.state.tableId, '1', reason: 'meja tidak berubah setelah tulis dikirim');
      expect(repo.created.single.$2, PestSeverity.ringan);
    });

    test('simpan ganda serentak diabaikan', () async {
      final repo = FakeRepo();
      final n = make(repo, (_) async => resultWith([det(0)]));
      await n.analyze(photo);
      await Future.wait([n.save(tableId: '1'), n.save(tableId: '1')]);
      expect(repo.uploads, 1);
      expect(repo.created, hasLength(1));
    });

    test('foto tanpa hama tetap bisa disimpan tanpa rekomendasi', () async {
      final repo = FakeRepo();
      final n = make(repo, (_) async => resultWith(const []));
      await n.analyze(photo);
      await n.save(tableId: '1');
      expect(n.state.phase, ScanPhase.saved);
      expect(repo.created, isEmpty);
      expect(repo.scans, 1);
    });

    test('analisis ulang membuang kunci, meja terkunci, dan hasil foto sebelumnya', () async {
      final repo = FakeRepo();
      final n = make(repo, (_) async => resultWith([det(0)]));
      await n.analyze(photo);
      await n.save(tableId: '1');
      await n.analyze(photo);
      expect(n.state.saveStarted, isFalse);
      expect(n.state.tableId, isNull);
      await n.save(tableId: '2');
      expect((repo.uploads, repo.scans), (2, 2));
      expect(repo.created[0].$3, isNot(repo.created[1].$3));
    });

    test('terima dua kali serentak: satu panggilan; hasil menggantikan kartu', () async {
      final repo = FakeRepo()..decisionGate = Completer<void>();
      final n = make(repo, (_) async => resultWith([det(0)]));
      await n.analyze(photo);
      await n.save(tableId: '1');
      final id = n.state.recommendations.single.id;
      final a = n.accept(id);
      final b = n.accept(id);
      repo.decisionGate!.complete();
      expect(await Future.wait([a, b]), [null, null]);
      expect(repo.decisionCalls, 1);
      expect(n.state.recommendations.single.status, RecommendationStatus.diterima);
    });
  });

  group('RecommendationDecider', () {
    test('ulangan dengan isi sama memakai kunci sama; isi berbeda mendapat kunci baru', () async {
      final repo = FakeRepo();
      final d = RecommendationDecider(repo);
      await d.accept('1', note: 'Sore');
      await d.accept('1', note: 'Sore');
      await d.accept('1', note: 'Pagi');
      await d.reject('2', RejectReason.harga);
      await d.reject('2', RejectReason.harga);
      await d.reject('2', RejectReason.tidakTersedia);
      const ten = StockLineDraft(inventoryId: '4', amount: '10', unit: 'ml');
      const twenty = StockLineDraft(inventoryId: '4', amount: '20', unit: 'ml');
      await d.accept('3', materials: const [ten]);
      await d.accept('3', materials: const [ten]);
      await d.accept('3', materials: const [twenty]);
      final k = repo.decisionKeys;
      expect(k[0], k[1]);
      expect(k[2], isNot(k[0]));
      expect(k[3], k[4]);
      expect(k[5], isNot(k[3]));
      expect(k[6], k[7], reason: 'bahan sama = kunci sama');
      expect(k[8], isNot(k[6]), reason: 'jumlah berbeda = kunci baru');
    });
  });

  group('PestHistoryNotifier', () {
    RecommendationPage page(List<PestRecommendation> items, {int p = 1, int total = 1}) =>
        RecommendationPage(items: items, page: p, totalPages: total);
    PestHistoryNotifier make(FakeRepo repo) => PestHistoryNotifier(repo, RecommendationDecider(repo));

    test('memuat halaman demi halaman dan berhenti di halaman terakhir', () async {
      final repo = FakeRepo()
        ..listFn = (s, k, p) => page([rec('$p', RecommendationStatus.menunggu)], p: p, total: 2);
      final n = make(repo);
      await n.refresh();
      await n.loadMore();
      await n.loadMore();
      expect(n.state.items.map((r) => r.id), ['1', '2']);
      expect(n.state.hasMore, isFalse);
    });

    test('filter meja diteruskan ke server dan bertahan saat filter lain berganti', () async {
      final repo = FakeRepo()..listFn = (s, k, p) => page(const []);
      final n = make(repo);
      await n.setTable('3');
      expect(repo.lastTableFilter, '3');
      await n.setStatus(RecommendationStatus.diterima);
      expect(repo.lastTableFilter, '3');
      await n.setTable(null);
      expect(repo.lastTableFilter, isNull);
    });

    test('ganti filter: hasil basi dari filter lama dibuang', () async {
      final repo = FakeRepo();
      final slow = Completer<RecommendationPage>();
      repo.gate = slow;
      final n = make(repo);
      final first = n.setStatus(RecommendationStatus.diterima);
      repo.gate = null;
      repo.listFn = (s, k, p) => page([rec('9', RecommendationStatus.ditolak)]);
      await n.setStatus(RecommendationStatus.ditolak);
      slow.complete(page([rec('1', RecommendationStatus.diterima)]));
      await first;
      expect(n.state.status, RecommendationStatus.ditolak);
      expect(n.state.items.map((r) => r.id), ['9']);
    });

    test('galat memuat tidak menghapus daftar yang sudah ada', () async {
      final repo = FakeRepo()..listFn = (s, k, p) => page([rec('1', RecommendationStatus.menunggu)]);
      final n = make(repo);
      await n.refresh();
      repo.listFn = (s, k, p) => throw const ApiException(503, 'DOWN', 'Server sibuk.');
      await n.refresh();
      expect(n.state.error, 'Server sibuk.');
      expect(n.state.items, hasLength(1));
    });

    test('terima pada filter "menunggu": baris keluar dari daftar; tanpa filter: berubah di tempat', () async {
      final repo = FakeRepo()
        ..listFn = (s, k, p) => page([rec('1', RecommendationStatus.menunggu), rec('2', RecommendationStatus.menunggu)]);
      final n = make(repo);
      await n.setStatus(RecommendationStatus.menunggu);
      await n.accept('1');
      expect(n.state.items.map((r) => r.id), ['2']);
      await n.setStatus(null);
      await n.reject('2', RejectReason.harga);
      expect(n.state.items.map((r) => (r.id, r.status)), [('1', RecommendationStatus.menunggu), ('2', RecommendationStatus.ditolak)]);
    });

    test('galat keputusan dikembalikan sebagai pesan dan daftar tetap', () async {
      final repo = _Failing()..listFn = (s, k, p) => page([rec('1', RecommendationStatus.menunggu)]);
      final n = make(repo);
      await n.refresh();
      expect(await n.accept('1'), 'Sudah diputuskan.');
      expect(n.state.items.single.status, RecommendationStatus.menunggu);
    });
  });
}

class _Failing extends FakeRepo {
  @override
  Future<PestRecommendation> accept(String id, {String? appliedOn, String? note, List<StockLineDraft> materials = const [], String? idempotencyKey}) async =>
      throw const ApiException(409, 'RECOMMENDATION_ALREADY_DECIDED', 'Sudah diputuskan.');
}
