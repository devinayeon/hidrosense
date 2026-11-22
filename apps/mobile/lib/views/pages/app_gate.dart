import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/session_viewmodel.dart';
import '../v2/pages/v2_beranda_connected_page.dart';
import '../v2/pages/v2_onboarding_page.dart';
import '../v2/v2_roles.dart';
import '../v2/v2_session_login.dart';

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
    // Tanda identitas yang menentukan kapan Navigator dibangun ulang: hanya
    // pergantian pengguna (masuk, keluar, atau ganti akun).
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
              // Container dipegang di awal: halaman login dilepas begitu sesi
              // terpasang, jadi `ref` halaman tidak aman dipakai sesudahnya.
              final container = ProviderScope.containerOf(
                context,
                listen: false,
              );
              return V2OnboardingPage(onLogin: v2SessionLogin(container));
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
