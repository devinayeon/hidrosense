import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/session_viewmodel.dart';
import 'pages/v2_login_page.dart';

/// Login sungguhan untuk halaman v2: memakai [SessionViewModel] dan
/// menerjemahkan kegagalannya ke layar alur v2 (1.7 salah, 1.8 akun
/// nonaktif, 1.9 perlu internet).
///
/// Begitu sesi terpasang, `AppGate` mengganti seluruh layar dengan beranda,
/// jadi pemanggil tidak perlu mengurus kelanjutannya.
Future<V2LoginResult> v2SessionLogin(
  WidgetRef ref,
  String username,
  String password,
) async {
  await ref.read(sessionProvider.notifier).login(username, password);
  final state = ref.read(sessionProvider);
  if (state.user != null) return const V2LoginResult.success();
  return switch (state.failure) {
    SessionFailure.invalidCredentials => const V2LoginResult(
      V2LoginOutcome.rejected,
    ),
    SessionFailure.accountDeactivated => const V2LoginResult(
      V2LoginOutcome.inactiveAccount,
    ),
    SessionFailure.offline => const V2LoginResult(V2LoginOutcome.offline),
    // Sisa kegagalan (mis. kuota permintaan) ditampilkan apa adanya.
    _ => V2LoginResult(V2LoginOutcome.rejected, message: state.error),
  };
}
