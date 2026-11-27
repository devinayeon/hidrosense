import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/table_record.dart';
import 'package:hidrosense_mobile/data/repositories/table_repository.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_detector.dart';
import 'package:hidrosense_mobile/features/pest/domain/pest_summary.dart';
import 'package:hidrosense_mobile/features/pest/domain/yolo_decoder.dart';
import 'package:hidrosense_mobile/features/pest/presentation/pages/pest_scan_page.dart';
import 'package:hidrosense_mobile/features/pest/presentation/viewmodels/pest_scan_viewmodel.dart';
import 'package:hidrosense_mobile/features/pest/presentation/viewmodels/recommendation_decider.dart';
import 'package:hidrosense_mobile/viewmodels/connected_table_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_segmented.dart';
import 'package:image_picker/image_picker.dart';

import 'pest_viewmodels_test.dart' show FakeRepo;
import 'support/damage_fixture.dart';

class _Session extends SessionViewModel {
  _Session(super.api, SessionUser user) : super(initialState: SessionState(user: user));
}

class _Tables extends ConnectedTableNotifier {
  _Tables(super.repo, List<TableRecord> rows) : super(canRead: false) {
    state = TableState(records: rows);
  }
}

SessionUser user(List<String> permissions) => SessionUser(
  id: '1', name: 'Petani', username: 'petani', role: 'petani', permissions: permissions,
);

const _table = TableRecord(id: '1', code: 'M-01', holeCount: 250, status: 'penuh', activePlants: 200);

// PNG 1x1 yang sah: deteksi diganti, Image.memory hanya perlu byte gambar yang benar.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

PestScanResult _result(int whiteflies) {
  final dets = [
    for (var i = 0; i < whiteflies; i++)
      const YoloDetection(classId: 0, confidence: 0.9, x1: 0.1, y1: 0.1, x2: 0.2, y2: 0.2),
  ];
  return PestScanResult(findings: summarizeDetections(dets), detections: dets, modelVersion: 'm');
}

const _petani = ['deteksi:write', 'rekomendasi:read', 'rekomendasi:decide', 'perawatan:write'];

Future<FakeRepo> pumpPage(
  WidgetTester tester, {
  List<String> permissions = _petani,
  int whiteflies = 2,
  FakeRepo? repo,
  Future<Uint8List?> Function(ImageSource)? pick,
  double textScale = 1,
  Size size = const Size(800, 2400),
  List<TableRecord> tables = const [_table],
}) async {
  // Layar ponsel tinggi supaya seluruh isi ListView dirender tanpa menggulir.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final api = apiFor((r) async => throw StateError('jaringan tidak dipakai'));
  addTearDown(api.close);
  final fake = repo ?? FakeRepo();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionProvider.overrideWith((ref) => _Session(api, user(permissions))),
      connectedTableProvider.overrideWith((ref) => _Tables(TableRepository(api), tables)),
      pestScanProvider.overrideWith((ref) => PestScanNotifier(
        (_) async => _result(whiteflies), fake, (t) async => 'batch-$t', RecommendationDecider(fake),
      )),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PestScanPage(pickPhoto: pick ?? (_) async => _png),
    ),
  ));
  await tester.pump();
  return fake;
}

Future<void> chooseTable(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('M-01').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('akun tanpa izin deteksi: pesan khusus petani, tanpa tombol kamera', (tester) async {
    await pumpPage(tester, permissions: const ['budidaya:read']);
    expect(find.text('Fitur ini hanya untuk akun petani.'), findsOneWidget);
    expect(find.text('Kamera'), findsNothing);
  });

  testWidgets('analisis lalu simpan: wajib pilih meja, kartu rekomendasi muncul setelah simpan', (tester) async {
    final repo = await pumpPage(tester);
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    expect(find.text('Kutu kebul: 2 terdeteksi'), findsOneWidget);
    expect(find.text('Pilih meja tanam dulu.'), findsOneWidget);
    await chooseTable(tester);
    expect(find.text('Pilih meja tanam dulu.'), findsNothing);
    await tester.tap(find.text('Simpan dan minta saran obat'));
    await tester.pumpAndSettle();
    expect(repo.uploads, 1);
    expect(repo.created.single.$1, PestKind.whitefly);
    expect(find.text('Spinosad'), findsOneWidget);
    expect(find.text('Terima'), findsOneWidget);
  });

  testWidgets('nol deteksi: kartu "bukan jaminan tanaman sehat", tombol simpan foto', (tester) async {
    await pumpPage(tester, whiteflies: 0);
    await tester.tap(find.text('Kamera'));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada hama terdeteksi'), findsOneWidget);
    expect(find.textContaining('bukan jaminan tanaman sehat'), findsOneWidget);
    expect(find.text('Simpan foto'), findsOneWidget);
  });

  testWidgets('simpan gagal: meja dan tingkat terkunci, coba lagi tidak mengunggah ulang', (tester) async {
    final repo = FakeRepo()..failCreateFor = PestKind.whitefly;
    await pumpPage(tester, repo: repo);
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    await chooseTable(tester);
    await tester.tap(find.text('Simpan dan minta saran obat'));
    await tester.pumpAndSettle();
    expect(find.text('Server sibuk.'), findsOneWidget);
    expect(find.text('Coba simpan lagi'), findsOneWidget);
    final dropdown = tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
    expect(dropdown.onChanged, isNull, reason: 'meja terkunci setelah tulis dikirim');
    final segmented = tester.widget<V2Segmented>(find.byType(V2Segmented));
    expect(segmented.onChanged, isNull, reason: 'tingkat terkunci setelah tulis dikirim');
    repo.failCreateFor = null;
    await tester.tap(find.text('Coba simpan lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Spinosad'), findsOneWidget);
    expect(repo.uploads, 1, reason: 'foto tidak diunggah ulang');
  });

  testWidgets('akses kamera ditolak: pesan jelas, halaman tetap jalan', (tester) async {
    await pumpPage(tester, pick: (_) async => throw PlatformException(code: 'camera_access_denied'));
    await tester.tap(find.text('Kamera'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Akses kamera atau galeri ditolak'), findsOneWidget);
    expect(find.text('Galeri'), findsOneWidget);
  });

  testWidgets('kapsul tingkat serangan tidak meluber di layar sempit', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    expect(find.byType(V2Segmented), findsOneWidget);

    // Lebar ponsel kecil lalu render ulang: dulu `SegmentedButton` bawaan
    // (dengan ikon centang) melebihi lebar kartu dan memicu overflow (BUG-15).
    tester.view.physicalSize = const Size(320, 2400);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('layar deteksi hama tidak meluber di skala teks 2.0', (tester) async {
    await pumpPage(tester, textScale: 2, size: const Size(360, 3000));
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    expect(find.text('Kutu kebul: 2 terdeteksi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tanpa meja berisi tanaman: daftar meja dijelaskan, bukan diam saja (K-28)', (
    tester,
  ) async {
    await pumpPage(tester, tables: const []);

    expect(
      find.textContaining('Belum ada meja dengan tanaman aktif'),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('overlay kotak deteksi tampil saat ada hama', (tester) async {
    await pumpPage(tester, whiteflies: 2);
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pest-detection-overlay')), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      'Foto tanaman dengan 2 kotak deteksi hama',
    );
  });

  testWidgets('overlay kotak deteksi tidak tampil saat nol deteksi', (tester) async {
    await pumpPage(tester, whiteflies: 0);
    await tester.tap(find.text('Kamera'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pest-detection-overlay')), findsNothing);
    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      'Foto tanaman yang dianalisis',
    );
  });

  test('projectDetectionToCanvas sejajar dengan area BoxFit.contain pada foto potret 20:9 yang dijepit', () {
    // Foto potret 900x2000 (rasio 0.45) dalam wadah terjepit 168x280 (rasio 0.6):
    // BoxFit.contain merender gambar 126x280 terpusat dengan bilah letterbox 21 px di kiri dan kanan.
    const canvasSize = Size(168, 280);
    final lb = computeLetterbox(900, 2000);
    final fullImgDet = YoloDetection(
      classId: 0,
      confidence: 0.9,
      x1: lb.left / lb.target,
      y1: lb.top / lb.target,
      x2: (lb.left + lb.newWidth) / lb.target,
      y2: (lb.top + lb.newHeight) / lb.target,
    );
    final rect = projectDetectionToCanvas(
      fullImgDet,
      canvasSize,
      imageWidth: 900,
      imageHeight: 2000,
    );
    expect(rect.left, closeTo(21.0, 0.5));
    expect(rect.right, closeTo(147.0, 0.5));
    expect(rect.top, closeTo(0.0, 0.5));
    expect(rect.bottom, closeTo(280.0, 0.5));
  });
}
