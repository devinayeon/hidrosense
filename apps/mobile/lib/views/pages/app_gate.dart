import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/session_viewmodel.dart';
import '../v2/pages/v2_beranda_connected_page.dart';
import '../v2/v2_roles.dart';
import 'login_page.dart';

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
    // Penanda identitas yang menentukan kapan Navigator dibangun ulang: hanya
    // pengguna. Beranda v1 (MainPage) sudah **dinonaktifkan sebagai jalur masuk**
    // (lihat D-15): begitu ada sesi, v2 selalu dipakai — termasuk saat sesi
    // dipulihkan setelah aplikasi dibuka ulang. Berkas/kode v1 tidak dihapus.
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
            if (user == null) return const LoginPage();
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
