import 'package:flutter/material.dart';

import 'pages/v2_onboarding_page.dart';
import 'theme/v2_tokens.dart';

/// Entry point pratinjau alur "01 Onboarding & Auth" tanpa login lama.
///
/// Jalankan dengan:
/// `flutter run -t lib/views/v2/v2_auth_preview_main.dart`
void main() => runApp(const V2AuthPreviewApp());

class V2AuthPreviewApp extends StatelessWidget {
  const V2AuthPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HidroSense v2 auth',
      debugShowCheckedModeBanner: false,
      theme: V2Theme.light,
      home: const V2OnboardingPage(),
    );
  }
}
