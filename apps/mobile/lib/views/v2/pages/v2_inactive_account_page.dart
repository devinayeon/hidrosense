import 'package:flutter/material.dart';

import '../components/v2_auth_assets.dart';
import '../components/v2_auth_state_view.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_button.dart';

/// Frame `1.8 Akun nonaktif`: akun dinonaktifkan petani, kembali ke login.
class V2InactiveAccountPage extends StatelessWidget {
  const V2InactiveAccountPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const V2InactiveAccountPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: V2AuthStateView(
            illustration: V2AuthAssets.inactiveAccount,
            title: 'Akun nonaktif',
            body: 'Hubungi petani untuk mengaktifkan akun.',
            topPadding: 76,
            actions: V2Button(
              label: 'Kembali',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}
