import 'package:flutter/material.dart';

import '../components/v2_auth_assets.dart';
import '../components/v2_auth_state_view.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_button.dart';

/// Frame `1.9 Offline saat masuk`: login pertama butuh internet.
///
/// Tombol Coba lagi menutup halaman ini sehingga pengguna kembali ke form
/// login yang masih terisi.
class V2OfflineLoginPage extends StatelessWidget {
  const V2OfflineLoginPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const V2OfflineLoginPage());
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
            illustration: V2AuthAssets.offlineLogin,
            title: 'Perlu internet',
            body: 'Masuk pertama butuh internet. Sambungkan, lalu coba lagi.',
            topPadding: 106,
            actions: V2Button(
              label: 'Coba lagi',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}
