import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

/// Dekoder dan praproses YOLOv11 untuk model `ml/artifacts/yolo11n_lettuce_pests.tflite`.
///
/// Port dari `ml/export_tflite.py` (decode_yolov11_output) dan `ml/evaluate.py`
/// (_letterbox_bgr_to_rgb_float). Paritasnya dijaga `test/pest_decoder_test.dart`
/// dengan golden dari model asli, jadi ubah keduanya bersamaan.
const int kYoloInput = 640;
const int kYoloAnchors = 8400;
const int kYoloClasses = 3;
const int kYoloChannels = 4 + kYoloClasses;
const double kYoloPadValue = 114;

/// Satu deteksi. Kotak ternormalisasi 0..1 pada ruang masukan 640x640 (setelah letterbox).
class YoloDetection {
  const YoloDetection({
    required this.classId,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final int classId;
  final double confidence;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

/// Pembulatan setengah-ke-genap seperti `round()` Python, supaya geometri letterbox sama persis.
int _pyRound(double x) {
  final floor = x.floorToDouble();
  final diff = x - floor;
  final base = floor.toInt();
  if (diff < 0.5) return base;
  if (diff > 0.5) return base + 1;
  return base.isEven ? base : base + 1;
}

/// Geometri letterbox: ukuran hasil resize dan pergeseran pad kiri/atas.
class Letterbox {
  const Letterbox({
    required this.originalWidth,
    required this.originalHeight,
    required this.newWidth,
    required this.newHeight,
    required this.left,
    required this.top,
    this.target = kYoloInput,
  });

  final int originalWidth;
  final int originalHeight;
  final int newWidth;
  final int newHeight;
  final int left;
  final int top;
  final int target;

  /// Kotak ruang masukan → koordinat foto asli, dijepit ke dalam foto.
  Rect toOriginal(YoloDetection d) {
    final scaleX = newWidth / originalWidth;
    final scaleY = newHeight / originalHeight;
    double fromX(double v) =>
        ((v * target - left) / scaleX).clamp(0.0, originalWidth.toDouble());
    double fromY(double v) =>
        ((v * target - top) / scaleY).clamp(0.0, originalHeight.toDouble());
    return Rect.fromLTRB(fromX(d.x1), fromY(d.y1), fromX(d.x2), fromY(d.y2));
  }
}

Letterbox computeLetterbox(int width, int height, {int target = kYoloInput}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Ukuran foto tidak valid: ${width}x$height');
  }
  final r = math.min(target / height, target / width);
  final newW = math.max(1, _pyRound(width * r));
  final newH = math.max(1, _pyRound(height * r));
  final dw = (target - newW) / 2.0;
  final dh = (target - newH) / 2.0;
  return Letterbox(
    originalWidth: width,
    originalHeight: height,
    newWidth: newW,
    newHeight: newH,
    left: _pyRound(dw - 0.1),
    top: _pyRound(dh - 0.1),
    target: target,
  );
}

/// Foto → tensor float32 NHWC [640*640*3], RGB 0..1, pad 114/255. Panggil setelah
/// `bakeOrientation` agar foto ponsel yang diputar lewat EXIF tidak miring.
Float32List letterboxToTensor(img.Image source) {
  final lb = computeLetterbox(source.width, source.height);
  var image = source.numChannels == 3 && source.format == img.Format.uint8
      ? source
      : source.convert(format: img.Format.uint8, numChannels: 3);
  if (image.width != lb.newWidth || image.height != lb.newHeight) {
    image = img.copyResize(
      image,
      width: lb.newWidth,
      height: lb.newHeight,
      interpolation: img.Interpolation.linear,
    );
  }
  final out = Float32List(kYoloInput * kYoloInput * 3)
    ..fillRange(0, kYoloInput * kYoloInput * 3, kYoloPadValue / 255.0);
  for (var y = 0; y < image.height; y++) {
    final ty = y + lb.top;
    if (ty < 0 || ty >= kYoloInput) continue;
    for (var x = 0; x < image.width; x++) {
      final tx = x + lb.left;
      if (tx < 0 || tx >= kYoloInput) continue;
      final p = image.getPixel(x, y);
      final o = (ty * kYoloInput + tx) * 3;
      out[o] = p.r / 255.0;
      out[o + 1] = p.g / 255.0;
      out[o + 2] = p.b / 255.0;
    }
  }
  return out;
}

double _iou(YoloDetection a, YoloDetection b) {
  final x1 = math.max(a.x1, b.x1);
  final y1 = math.max(a.y1, b.y1);
  final x2 = math.min(a.x2, b.x2);
  final y2 = math.min(a.y2, b.y2);
  final inter = math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
  if (inter <= 0) return 0;
  final areaA = math.max(0.0, a.x2 - a.x1) * math.max(0.0, a.y2 - a.y1);
  final areaB = math.max(0.0, b.x2 - b.x1) * math.max(0.0, b.y2 - b.y1);
  return inter / math.max(1e-8, areaA + areaB - inter);
}

/// Keluaran model [1, 7, 8400] yang sudah diratakan (channel-first): baris 0..3 = cx, cy, w, h,
/// baris 4..6 = skor thrips, whitefly, aphids. Tensor dengan ukuran lain menandakan model salah
/// dan ditolak keras, bukan diam-diam menghasilkan nol deteksi.
List<YoloDetection> decodeYolov11Output(
  Float32List output, {
  int anchors = kYoloAnchors,
  int imgSize = kYoloInput,
  double confThreshold = 0.35,
  double iouThreshold = 0.45,
}) {
  if (output.isEmpty) return const [];
  if (output.length != kYoloChannels * anchors) {
    throw ArgumentError(
      'Keluaran model berukuran ${output.length}, diharapkan ${kYoloChannels * anchors}.',
    );
  }
  double at(int ch, int i) => output[ch * anchors + i];

  final valid = <int>[];
  var maxCoord = 0.0;
  for (var i = 0; i < anchors; i++) {
    var finite = true;
    for (var ch = 0; ch < kYoloChannels; ch++) {
      if (!at(ch, i).isFinite) {
        finite = false;
        break;
      }
    }
    if (!finite) continue;
    valid.add(i);
    for (var ch = 0; ch < 4; ch++) {
      maxCoord = math.max(maxCoord, at(ch, i));
    }
  }
  final pixelCoords = maxCoord > 1.5;
  final scale = imgSize.toDouble();

  final candidates = <(int, YoloDetection)>[];
  for (final i in valid) {
    var best = 0;
    var bestScore = at(4, i);
    for (var c = 1; c < kYoloClasses; c++) {
      if (at(4 + c, i) > bestScore) {
        best = c;
        bestScore = at(4 + c, i);
      }
    }
    if (bestScore < confThreshold) continue;
    var cx = at(0, i);
    var cy = at(1, i);
    var w = at(2, i);
    var h = at(3, i);
    if (pixelCoords) {
      cx /= scale;
      cy /= scale;
      w /= scale;
      h /= scale;
    }
    final x1 = (cx - w / 2).clamp(0.0, 1.0);
    final y1 = (cy - h / 2).clamp(0.0, 1.0);
    final x2 = (cx + w / 2).clamp(0.0, 1.0);
    final y2 = (cy + h / 2).clamp(0.0, 1.0);
    if (x2 <= x1 || y2 <= y1) continue;
    candidates.add((
      i,
      YoloDetection(
        classId: best,
        confidence: (bestScore * 10000).roundToDouble() / 10000,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
      ),
    ));
  }
  // Urut menurun menurut skor; imbang dipecah menurut urutan jangkar (sama dengan sort stabil Python).
  candidates.sort((a, b) {
    final byScore = b.$2.confidence.compareTo(a.$2.confidence);
    return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
  });

  final selected = <YoloDetection>[];
  for (final (_, cand) in candidates) {
    final suppressed = selected.any(
      (kept) => kept.classId == cand.classId && _iou(cand, kept) > iouThreshold,
    );
    if (!suppressed) selected.add(cand);
  }
  return selected;
}
