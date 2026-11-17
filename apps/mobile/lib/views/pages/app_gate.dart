import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/session_viewmodel.dart';
import '../v2/pages/v2_beranda_page.dart';
import '../v2/v2_ui_mode.dart';
import 'login_page.dart';
import 'main_page.dart';

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
    final useV2 = ref.watch(v2UiModeProvider);
    // Tanda identitas yang menentukan kapan Navigator dibangun ulang: pengguna,
    // dan mode v2 yang hanya berarti kalau sudah ada pengguna.
    //
    // Perubahan mode saat belum ada sesi (mis. alur v2 ditandai selagi login
    // berlangsung) **tidak** ikut dibangun ulang, karena itu akan membuang
    // tumpukan rute pratinjau yang sedang dibuka.
    final identity = '${user?.id ?? ''}|${user == null ? '' : useV2}';
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
            if (!useV2) return const MainPage();
            return V2BerandaPage(
              userName: user.name,
              role: user.role == 'pegawai'
                  ? V2BerandaRole.pegawai
                  : V2BerandaRole.petani,
            );
          },
        ),
      ),
    );
  }
}
