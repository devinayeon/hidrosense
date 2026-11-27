import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../viewmodels/connected_table_viewmodel.dart';
import '../../../../viewmodels/session_viewmodel.dart';
import '../../../../views/v2/theme/v2_tokens.dart';
import '../../../../views/v2/widgets/v2_banner.dart';
import '../../../../views/v2/widgets/v2_button.dart';
import '../../../../views/v2/widgets/v2_card.dart';
import '../../../../views/v2/widgets/v2_segmented.dart';
import '../../domain/pest_summary.dart';
import '../../domain/yolo_decoder.dart';
import '../viewmodels/pest_scan_viewmodel.dart';
import '../widgets/decision_sheets.dart';
import 'rotation_history_page.dart';

/// Foto tanaman → deteksi hama di perangkat → saran rotasi obat per hama.
///
/// Analisis berjalan offline. Foto baru diunggah setelah pengguna menekan Simpan.
class PestScanPage extends ConsumerStatefulWidget {
  const PestScanPage({super.key, this.pickPhoto});

  /// Diganti di tes; bawaannya kamera atau galeri lewat image_picker.
  final Future<Uint8List?> Function(ImageSource source)? pickPhoto;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const PestScanPage());

  @override
  ConsumerState<PestScanPage> createState() => _PestScanPageState();
}

class _PestScanPageState extends ConsumerState<PestScanPage> {
  String? _tableId;
  String? _pickError;

  Future<Uint8List?> _pick(ImageSource source) async {
    final custom = widget.pickPhoto;
    if (custom != null) return custom(source);
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 90);
    return file?.readAsBytes();
  }

  Future<void> _capture(ImageSource source) async {
    setState(() => _pickError = null);
    try {
      final bytes = await _pick(source);
      if (bytes == null || !mounted) return;
      await ref.read(pestScanProvider.notifier).analyze(bytes);
    } on PlatformException {
      if (mounted) setState(() => _pickError = 'Akses kamera atau galeri ditolak. Izinkan lewat pengaturan perangkat.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final allowed = user?.permissions.contains('deteksi:write') ?? false;
    final state = ref.watch(pestScanProvider);
    final notifier = ref.read(pestScanProvider.notifier);
    final tables = ref.watch(connectedTableProvider).records.where((t) => !t.isInactive && t.activePlants > 0).toList();
    final busy = state.phase == ScanPhase.analyzing || state.phase == ScanPhase.saving;
    final tableId = state.tableId ?? _tableId;
    void save() => notifier.save(tableId: tableId!);

    return Scaffold(
      backgroundColor: V2Colors.canvas,
      appBar: AppBar(
        title: const Text('Foto tanaman'),
        actions: [
          IconButton(
            tooltip: 'Riwayat rotasi obat',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(RotationHistoryPage.route()),
          ),
        ],
      ),
      body: !allowed
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(V2Space.xl),
                child: Text('Fitur ini hanya untuk akun petani.', style: V2Type.body, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(V2Space.lg),
              children: [
                const V2Banner(
                  message: 'Foto daun dari dekat (10–25 cm) agar hama jelas. Deteksi di HP hanya saran.',
                  tone: V2BannerTone.ai,
                ),
                const SizedBox(height: V2Space.lg),
                DropdownButtonFormField<String>(
                  initialValue: tables.any((t) => t.id == tableId) ? tableId : null,
                  decoration: const InputDecoration(labelText: 'Meja tanam'),
                  items: [for (final t in tables) DropdownMenuItem(value: t.id, child: Text(t.code))],
                  // Terkunci sejak simpan dimulai: foto sudah terikat ke batch meja itu.
                  onChanged: busy || state.saveStarted ? null : (value) => setState(() => _tableId = value),
                ),
                if (tables.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: V2Space.sm),
                    child: Text(
                      'Belum ada meja dengan tanaman aktif. Pindahkan semaian ke meja dulu, lalu kembali ke sini.',
                      style: V2Type.caption,
                    ),
                  ),
                const SizedBox(height: V2Space.lg),
                Row(
                  children: [
                    Expanded(
                      child: V2Button(
                        label: 'Kamera',
                        state: busy ? V2ButtonState.disabled : V2ButtonState.normal,
                        onPressed: () => _capture(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: V2Space.md),
                    Expanded(
                      child: V2Button(
                        label: 'Galeri',
                        type: V2ButtonType.secondary,
                        state: busy ? V2ButtonState.disabled : V2ButtonState.normal,
                        onPressed: () => _capture(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                if (_pickError != null) _ErrorText(_pickError!),
                if (state.photo != null) ...[
                  const SizedBox(height: V2Space.lg),
                  _PhotoPreviewWithDetections(
                    bytes: state.photo!,
                    detections: state.phase == ScanPhase.analyzing
                        ? const []
                        : (state.result?.detections ?? const []),
                    imageWidth: state.result?.imageWidth,
                    imageHeight: state.result?.imageHeight,
                  ),
                ],
                if (state.phase == ScanPhase.analyzing) ...[
                  const SizedBox(height: V2Space.lg),
                  const Center(child: CircularProgressIndicator(semanticsLabel: 'Menganalisis foto')),
                  const SizedBox(height: V2Space.sm),
                  const Center(child: Text('Menganalisis foto…', style: V2Type.caption)),
                ],
                if (state.error != null) _ErrorText(state.error!),
                if (state.canRetrySave) ...[
                  const SizedBox(height: V2Space.md),
                  V2Button(label: 'Coba simpan lagi', onPressed: save),
                ],
                if (state.result != null && state.phase != ScanPhase.analyzing) ..._result(state, notifier, busy, tableId, save),
              ],
            ),
    );
  }

  List<Widget> _result(PestScanState state, PestScanNotifier notifier, bool busy, String? tableId, VoidCallback save) {
    final result = state.result!;
    return [
      const SizedBox(height: V2Space.lg),
      if (result.isEmpty)
        const V2Card(
          title: 'Tidak ada hama terdeteksi',
          body: 'Ini bukan jaminan tanaman sehat. Periksa sisi bawah daun dan pucuk, lalu foto ulang bila ragu.',
        )
      else
        for (final f in result.findings) ...[
          V2Card(
            padding: const EdgeInsets.all(V2Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${f.kind.label}: ${f.count} terdeteksi', style: V2Type.h2),
                Text('Keyakinan tertinggi ${(f.maxConfidence * 100).round()}%', style: V2Type.caption),
                const SizedBox(height: V2Space.md),
                const Text('Tingkat serangan', style: V2Type.label),
                const SizedBox(height: V2Space.xs),
                // Kontrol kapsul milik desain v2, bukan `SegmentedButton` bawaan
                // Material. Tiga kapsul Ringan/Sedang/Berat dulu bisa meluber
                // keluar kartu (BUG-15) karena lebarnya mengikuti isi (termasuk
                // ikon centang). V2Segmented membagi lebar sama rata dan
                // memotong teks dengan elipsis bila ruang sempit.
                V2Segmented(
                  labels: [for (final s in PestSeverity.values) s.label],
                  selectedIndex: PestSeverity.values.indexOf(
                    state.severities[f.kind] ?? f.suggestedSeverity,
                  ),
                  onChanged: state.canEditSeverity && !busy
                      ? (index) => notifier.setSeverity(
                            f.kind,
                            PestSeverity.values[index],
                          )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: V2Space.md),
        ],
      if (state.phase == ScanPhase.analyzed || state.phase == ScanPhase.saving) ...[
        V2Button(
          label: result.isEmpty ? 'Simpan foto' : 'Simpan dan minta saran obat',
          expand: true,
          state: tableId == null
              ? V2ButtonState.disabled
              : busy
              ? V2ButtonState.loading
              : V2ButtonState.normal,
          onPressed: tableId == null || busy ? null : save,
        ),
        if (tableId == null)
          const Padding(
            padding: EdgeInsets.only(top: V2Space.sm),
            child: Text('Pilih meja tanam dulu.', style: V2Type.caption),
          ),
      ],
      for (final rec in state.recommendations) ...[
        const SizedBox(height: V2Space.lg),
        DecidableRecommendationCard(
          key: ValueKey(rec.id),
          recommendation: rec,
          onAccept: notifier.accept,
          onReject: notifier.reject,
          stock: stockOptions(ref),
        ),
      ],
    ];
  }
}

class _PhotoPreviewWithDetections extends StatelessWidget {
  const _PhotoPreviewWithDetections({
    required this.bytes,
    required this.detections,
    this.imageWidth,
    this.imageHeight,
  });

  final Uint8List bytes;
  final List<YoloDetection> detections;
  final int? imageWidth;
  final int? imageHeight;

  @override
  Widget build(BuildContext context) {
    final hasBoxes = detections.isNotEmpty;
    final imgW = imageWidth;
    final imgH = imageHeight;
    final aspect = (imgW != null && imgH != null && imgW > 0 && imgH > 0)
        ? (imgW / imgH).clamp(0.6, 2.0)
        : 4 / 3;

    return ClipRRect(
      borderRadius: BorderRadius.circular(V2Radius.iconBox),
      child: Container(
        color: V2Colors.charcoal900,
        constraints: const BoxConstraints(maxHeight: 280),
        width: double.infinity,
        child: Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  semanticLabel: hasBoxes
                      ? 'Foto tanaman dengan ${detections.length} kotak deteksi hama'
                      : 'Foto tanaman yang dianalisis',
                ),
                if (hasBoxes)
                  IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey('pest-detection-overlay'),
                      painter: _DetectionBoxesPainter(
                        detections: detections,
                        imageWidth: imgW,
                        imageHeight: imgH,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Memetakan satu deteksi YOLO (ruang letterbox 640x640 ternormalisasi) ke koordinat piksel
/// kanvas yang menampilkan foto dengan [BoxFit.contain], termasuk saat rasio aspek dijepit.
@visibleForTesting
Rect projectDetectionToCanvas(
  YoloDetection d,
  Size canvasSize, {
  int? imageWidth,
  int? imageHeight,
}) {
  if (imageWidth != null && imageHeight != null && imageWidth > 0 && imageHeight > 0) {
    final lb = computeLetterbox(imageWidth, imageHeight);
    final inOrig = lb.toOriginal(d);
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(imageWidth.toDouble(), imageHeight.toDouble()),
      canvasSize,
    );
    final dest = Alignment.center.inscribe(fitted.destination, Offset.zero & canvasSize);
    final sx = dest.width / imageWidth;
    final sy = dest.height / imageHeight;
    return Rect.fromLTRB(
      (dest.left + inOrig.left * sx).clamp(dest.left, dest.right),
      (dest.top + inOrig.top * sy).clamp(dest.top, dest.bottom),
      (dest.left + inOrig.right * sx).clamp(dest.left, dest.right),
      (dest.top + inOrig.bottom * sy).clamp(dest.top, dest.bottom),
    );
  }
  return Rect.fromLTRB(
    (d.x1 * canvasSize.width).clamp(0.0, canvasSize.width),
    (d.y1 * canvasSize.height).clamp(0.0, canvasSize.height),
    (d.x2 * canvasSize.width).clamp(0.0, canvasSize.width),
    (d.y2 * canvasSize.height).clamp(0.0, canvasSize.height),
  );
}

class _DetectionBoxesPainter extends CustomPainter {
  const _DetectionBoxesPainter({
    required this.detections,
    this.imageWidth,
    this.imageHeight,
  });

  final List<YoloDetection> detections;
  final int? imageWidth;
  final int? imageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      final rect = projectDetectionToCanvas(
        d,
        size,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
      if (rect.width < 2 || rect.height < 2) continue;

      final strokeColor = d.classId == 0 ? V2Colors.blue600 : V2Colors.amber800;
      final borderPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        borderPaint,
      );

      final kindLabel = (d.classId >= 0 && d.classId < PestKind.modelClasses.length)
          ? PestKind.modelClasses[d.classId].label
          : 'Hama';
      final label = '$kindLabel ${(d.confidence * 100).round()}%';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: V2Type.caption.copyWith(
            color: V2Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);

      final pillW = tp.width + 8;
      final pillH = tp.height + 4;
      final pillLeft = rect.left.clamp(0.0, (size.width - pillW).clamp(0.0, size.width));
      final pillTop = (rect.top - pillH >= 0) ? rect.top - pillH : rect.top;
      final pillRect = Rect.fromLTWH(pillLeft, pillTop, pillW, pillH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(pillRect, const Radius.circular(4)),
        Paint()..color = strokeColor,
      );
      tp.paint(canvas, Offset(pillLeft + 4, pillTop + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionBoxesPainter oldDelegate) =>
      oldDelegate.detections != detections ||
      oldDelegate.imageWidth != imageWidth ||
      oldDelegate.imageHeight != imageHeight;
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: V2Space.md),
    child: Text(message, style: V2Type.body.copyWith(color: V2Colors.red700)),
  );
}
