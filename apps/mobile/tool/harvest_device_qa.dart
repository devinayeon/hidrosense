import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hidrosense_mobile/views/pages/app_gate.dart';
import 'package:hidrosense_mobile/views/v2/theme/v2_tokens.dart';

void main() {
  if (!kDebugMode) {
    throw StateError('Harvest device QA requires a debug build.');
  }
  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: V2Theme.light,
        home: const AppGate(),
      ),
    ),
  );
}
