import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Isi halaman status autentik (akun nonaktif, offline, izin notifikasi).
///
/// Susunan mengikuti frame FigCraft: ilustrasi 320, judul 28, badan 16, lalu
/// aksi menempel di bawah. `topPadding` mengatur jarak dari status bar sesuai
/// frame asal (1.8, 1.9, 1.10).
class V2AuthStateView extends StatelessWidget {
  const V2AuthStateView({
    super.key,
    required this.illustration,
    required this.title,
    required this.body,
    required this.actions,
    this.topPadding = 76,
  });

  final String illustration;
  final String title;
  final String body;
  final Widget actions;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            V2Space.xl,
            0,
            V2Space.xl,
            V2Space.xxxl + 2,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - V2Space.xxxl - 2,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: topPadding),
                  ExcludeSemantics(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.asset(
                            illustration,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: V2Space.lg),
                  Text(title, textAlign: TextAlign.center, style: V2Type.h1),
                  const SizedBox(height: V2Space.lg),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: V2Type.body.copyWith(color: V2Colors.muted),
                  ),
                  const Spacer(),
                  actions,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
