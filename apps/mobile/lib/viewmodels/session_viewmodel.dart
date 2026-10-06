import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../data/services/api_client.dart';

export '../data/services/api_client.dart' show SessionUser;

final apiClientProvider = Provider<ApiClient>((ref) {
  const address = String.fromEnvironment('API_BASE_URL');
  final api = ApiClient(
    http.Client(),
    baseUri: Uri.tryParse(address) ?? Uri(),
    allowInsecureLocalhost: kDebugMode,
  );
  ref.onDispose(api.close);
  return api;
});

class SessionState {
  const SessionState({this.user, this.busy = false, this.error});
  final SessionUser? user;
  final bool busy;
  final String? error;
}

String serviceError(Object error) => error is ApiException
    ? error.message
    : error is FormatException
    ? 'Data layanan tidak sesuai. Coba lagi.'
    : 'Tidak dapat menghubungi layanan. Periksa koneksi lalu coba lagi.';

class SessionViewModel extends StateNotifier<SessionState> {
  SessionViewModel(this._api, {SessionState? initialState})
    : super(initialState ?? const SessionState()) {
    _api.onSessionExpired = () {
      if (mounted) {
        state = const SessionState(error: 'Sesi berakhir. Masuk kembali.');
      }
    };
  }
  final ApiClient _api;
  int _operation = 0;

  Future<void> login(String username, String password) async {
    if (state.busy) return;
    final operation = ++_operation;
    state = const SessionState(busy: true);
    try {
      final user = await _api.login(username, password);
      if (mounted && operation == _operation) state = SessionState(user: user);
    } catch (error) {
      if (mounted && operation == _operation) {
        state = SessionState(error: serviceError(error));
      }
    }
  }

  Future<void> logout() async {
    ++_operation;
    // Remove account data from the screen immediately, even without a network.
    state = const SessionState(busy: true);
    try {
      await _api.logout();
      if (mounted) state = const SessionState();
    } catch (_) {
      if (mounted) {
        state = const SessionState(
          error:
              'Keluar dari perangkat. Pencabutan sesi server belum terkonfirmasi.',
        );
      }
    }
  }

  @override
  void dispose() {
    _api.onSessionExpired = null;
    super.dispose();
  }
}

final sessionProvider = StateNotifierProvider<SessionViewModel, SessionState>(
  (ref) => SessionViewModel(ref.watch(apiClientProvider)),
);
