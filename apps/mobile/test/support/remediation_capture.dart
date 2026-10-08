import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadCaptureFonts() async {
  if (Platform.environment['RECORD_REMEDIATION_UI'] != '1' ||
      !Platform.isWindows) {
    return;
  }
  final bytes = await File(r'C:\Windows\Fonts\segoeui.ttf').readAsBytes();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  for (final family in ['Inter', 'Roboto', 'Ahem']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Future<void> captureRemediation(WidgetTester tester, String name) async {
  if (Platform.environment['RECORD_REMEDIATION_UI'] != '1') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('remediation-capture')),
  );
  await tester.runAsync(() async {
    final rendered = await boundary.toImage(pixelRatio: 2);
    try {
      final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/remediation-verification');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
    } finally {
      rendered.dispose();
    }
  });
}
