import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_auth_assets.dart';

/// Kop halaman login: logo maskot, judul, dan keterangan singkat.
///
/// Frame FigCraft `1.5 Login kosong` memakai logo 81x112 lalu jarak 16 ke
/// judul 28/36 dan 16 lagi ke badan 16/24.
class V2LoginBrand extends StatelessWidget {
  const V2LoginBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 81,
          height: 112,
          child: ColoredBox(
            color: V2Colors.white,
            child: Image.asset(
              V2AuthAssets.loginMascot,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
        ),
        const SizedBox(height: V2Space.lg),
        Text('Masuk', style: V2Type.h1),
        const SizedBox(height: V2Space.lg),
        Text(
          'Akun dibuat oleh petani.',
          style: V2Type.body.copyWith(color: V2Colors.muted),
        ),
      ],
    );
  }
}
