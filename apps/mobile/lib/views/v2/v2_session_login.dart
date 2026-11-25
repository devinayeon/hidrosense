import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/session_viewmodel.dart';
import 'pages/v2_login_page.dart';

/// Login nyata untuk alur v2: memakai `SessionViewModel` lalu menerjemahkan
/// kegagalannya ke layar alur v2 (1.7 salah, 1.8 akun nonaktif, 1.9 perlu
/// internet).
///
/// Memakai [ProviderContainer] yang dipegang di awal, bukan `ref` milik
/// halaman: begitu sesi terpasang, `AppGate` mengganti seluruh layar dan
/// melepas halaman login, jadi `ref` halaman tidak aman dipakai sesudahnya.
V2LoginHandler v2SessionLogin(ProviderContainer container) {
  return (String username, String password) async {
    await container.read(sessionProvider.notifier).login(username, password);
    final session = container.read(sessionProvider);
    if (session.user != null) return const V2LoginResult.success();
    return switch (session.failure) {
      SessionFailure.invalidCredentials => const V2LoginResult(
        V2LoginOutcome.rejected,
      ),
      SessionFailure.accountDeactivated => const V2LoginResult(
        V2LoginOutcome.inactiveAccount,
      ),
      SessionFailure.offline => const V2LoginResult(V2LoginOutcome.offline),
      // Sisa kegagalan (mis. kuota permintaan) ditampilkan apa adanya.
      _ => V2LoginResult(V2LoginOutcome.rejected, message: session.error),
    };
  };
}
