import 'package:flutter/material.dart';

import 'pages/v2_gallery_page.dart';
import 'theme/v2_tokens.dart';

/// Entry point sementara untuk melihat galeri v2 tanpa login.
///
/// Jalankan dengan:
/// `flutter run -t lib/views/v2/v2_preview_main.dart`
void main() => runApp(const V2PreviewApp());

class V2PreviewApp extends StatelessWidget {
  const V2PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HidroSense v2 preview',
      debugShowCheckedModeBanner: false,
      theme: V2Theme.light,
      home: const V2GalleryPage(),
    );
  }
}
