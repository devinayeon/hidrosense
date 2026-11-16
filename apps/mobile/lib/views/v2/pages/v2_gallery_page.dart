import 'package:flutter/material.dart';

import '../components/v2_foundation_gallery.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_error_state.dart';

/// Halaman review semua widget reusable v2.
///
/// Halaman ini sengaja hanya berisi galeri: belum ada alur bisnis, tujuannya
/// supaya desain bisa dicek langsung di perangkat sebelum dirakit jadi layar.
class V2GalleryPage extends StatelessWidget {
  const V2GalleryPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const V2GalleryPage());

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: V2Colors.canvas,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: SafeArea(
              bottom: false,
              child: V2AppBar(
                title: 'Review widget v2',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                V2Space.lg,
                V2Space.lg,
                V2Space.lg,
                V2Space.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  V2FlowNote(
                    title: 'HidroSense v2',
                    note:
                        'Semua widget di halaman ini disadur dari '
                        '"00 Foundations". Pakai token V2Colors, V2Type, dan '
                        'V2Space supaya tampilan tetap konsisten.',
                    roleLabel: 'Review internal',
                  ),
                  SizedBox(height: V2Space.xl),
                  V2FoundationGallery(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
