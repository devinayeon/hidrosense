import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/session_viewmodel.dart';
import '../v2/pages/v2_beranda_connected_page.dart';
import '../v2/pages/v2_onboarding_page.dart';
import '../v2/v2_roles.dart';
import '../v2/v2_session_login.dart';

/// Pintu masuk aplikasi: tampilan v2 saja.
///
/// Tanpa sesi: splash, perkenalan, lalu login v2. Dengan sesi: beranda v2.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _identity;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider.select((state) => state.user));
    // Navigator dibangun ulang hanya saat pengguna berganti, supaya tumpukan
    // rute sesi lama tidak terbawa ke sesi berikutnya.
    final identity = user?.id ?? '';
    if (identity != _identity) {
      _identity = identity;
      _navigatorKey = GlobalKey<NavigatorState>();
    }

    return NavigatorPopHandler<Object?>(
      onPopWithResult: (result) => _navigatorKey.currentState?.maybePop(result),
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) {
            if (user == null) {
              return V2OnboardingPage(
                onLogin: (username, password) =>
                    v2SessionLogin(ref, username, password),
              );
            }
            return V2BerandaConnectedPage(
              userName: user.name,
              fullName: user.name,
              username: user.username,
              role: user.role == 'pegawai'
                  ? V2BerandaRole.pegawai
                  : V2BerandaRole.petani,
              onLogOut: () => ref.read(sessionProvider.notifier).logout(),
            );
          },
        ),
      ),
    );
  }
}
