import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// docs/ARCHITECTURE.md (Peta MVC): panggilan satu arah View -> ViewModel -> Repository/Service.
/// Review 2026-11-23 menemukan `data/services/weather_background.dart` mengimpor viewmodel.
/// Lapisan Model (data, models, core, domain fitur) tidak boleh mengimpor lapisan di atasnya.
void main() {
  const modelLayers = ['lib/data', 'lib/models', 'lib/core', 'lib/features/pest/data', 'lib/features/pest/domain'];
  final upward = RegExp(r'''^import\s+['"][^'"]*(/viewmodels/|/views/|/presentation/)''', multiLine: true);

  test('lapisan Model tidak mengimpor ViewModel atau View', () {
    final offenders = <String>[];
    for (final dir in modelLayers) {
      final root = Directory(dir);
      expect(root.existsSync(), isTrue, reason: '$dir hilang; perbarui daftar lapisan');
      for (final file in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        for (final match in upward.allMatches(file.readAsStringSync())) {
          offenders.add('${file.path}: ${match.group(0)}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
