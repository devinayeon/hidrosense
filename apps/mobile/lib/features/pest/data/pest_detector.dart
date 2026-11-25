import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../domain/pest_summary.dart';
import '../domain/yolo_decoder.dart';

const String kPestModelAsset = 'assets/ml/yolo11n_lettuce_pests.tflite';
const String kPestMetadataAsset = 'assets/ml/model_metadata.json';

/// Hasil pindai satu foto.
class PestScanResult {
  const PestScanResult({
    required this.findings,
    required this.detections,
    required this.modelVersion,
  });

  final List<PestFinding> findings;
  final List<YoloDetection> detections;
  final String modelVersion;

  bool get isEmpty => detections.isEmpty;
}

/// Dekode, putar sesuai EXIF, lalu letterbox. Dijalankan di isolate: foto ponsel 12 MP
/// membutuhkan ratusan milidetik dan akan membekukan UI bila di thread utama.
Float32List _prepare(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Berkas bukan foto yang bisa dibaca.');
  }
  final upright = img.bakeOrientation(decoded);
  return letterboxToTensor(upright);
}

/// Model YOLOv11n yang ditanam di aplikasi (`assets/ml/`), berjalan sepenuhnya di perangkat.
///
/// Belum diuji di perangkat nyata dari sini: tes unit hanya mencakup praproses dan dekoder
/// (paritas dengan Python). Waktu inferensi dan kompatibilitas delegate perlu diukur di ponsel.
class PestDetector {
  PestDetector._(
    this._interpreter,
    this.modelVersion, {
    required this.defaultConfThreshold,
    required this.defaultIouThreshold,
  });

  final Interpreter _interpreter;
  final String modelVersion;
  final double defaultConfThreshold;
  final double defaultIouThreshold;

  static Future<PestDetector> load({
    String modelAsset = kPestModelAsset,
    String metadataAsset = kPestMetadataAsset,
  }) async {
    final metadata =
        jsonDecode(await rootBundle.loadString(metadataAsset))
            as Map<String, dynamic>;
    final interpreter = await Interpreter.fromAsset(
      modelAsset,
      options: InterpreterOptions()..threads = 2,
    );
    final input = interpreter.getInputTensor(0).shape;
    final output = interpreter.getOutputTensor(0).shape;
    if (!listEquals(input, const [1, kYoloInput, kYoloInput, 3]) ||
        !listEquals(output, const [1, kYoloChannels, kYoloAnchors])) {
      interpreter.close();
      throw StateError(
        'Bentuk model tidak sesuai kontrak: masukan $input, keluaran $output.',
      );
    }
    return PestDetector._(
      interpreter,
      metadata['model_version'] as String,
      defaultConfThreshold:
          (metadata['confidence_threshold'] as num?)?.toDouble() ?? 0.45,
      defaultIouThreshold:
          (metadata['iou_threshold'] as num?)?.toDouble() ?? 0.45,
    );
  }

  Future<PestScanResult> detect(
    Uint8List photoBytes, {
    double? confThreshold,
    double? iouThreshold,
  }) async {
    final tensor = await compute(_prepare, photoBytes);
    _interpreter.getInputTensor(0).data = tensor.buffer.asUint8List();
    _interpreter.invoke();
    final raw = _interpreter.getOutputTensor(0).data;
    final output = Float32List.view(
      raw.buffer,
      raw.offsetInBytes,
      raw.lengthInBytes ~/ 4,
    );
    final detections = decodeYolov11Output(
      output,
      confThreshold: confThreshold ?? defaultConfThreshold,
      iouThreshold: iouThreshold ?? defaultIouThreshold,
    );
    return PestScanResult(
      findings: summarizeDetections(detections),
      detections: detections,
      modelVersion: modelVersion,
    );
  }

  void dispose() => _interpreter.close();
}
