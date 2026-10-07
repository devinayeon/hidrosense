import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../data/services/api_client.dart';

export '../data/services/api_client.dart' show SessionUser;

Uri resolveApiBaseUri([String? customAddress]) {
  final raw = (customAddress ?? const String.fromEnvironment('API_BASE_URL')).trim();
  if (raw.isNotEmpty) {
    var uri = Uri.tryParse(raw) ?? Uri();
    if (uri.hasScheme && uri.hasAuthority) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // USB debugging uses `adb reverse`, which exposes the host service at
        // 127.0.0.1 on a physical device. Keep 10.0.2.2 for emulator runs.
        // An explicit API_BASE_URL is authoritative and must not be rewritten.
      }
      final pathWithoutSlash = uri.path.replaceAll(RegExp(r'/+$'), '');
      if (!pathWithoutSlash.endsWith('/api/v1')) {
        uri = uri.replace(
          path: pathWithoutSlash.isEmpty ? '/api/v1' : '$pathWithoutSlash/api/v1',
        );
      }
      return uri;
    }
  }

  if (kDebugMode) {
    return Uri.parse('http://127.0.0.1:3000/api/v1');
  }

  return Uri();
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUri = resolveApiBaseUri();
  if (kDebugMode) {
    debugPrint('[ApiClient] Initialized baseUri: $baseUri');
  }
  final api = ApiClient(
    http.Client(),
    baseUri: baseUri,
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

String serviceError(Object error) {
  if (kDebugMode) {
    debugPrint('[SessionViewModel] Request error: $error');
  }
  return error is ApiException
      ? error.message
      : error is FormatException
      ? 'Data layanan tidak sesuai. Coba lagi.'
      : 'Tidak dapat menghubungi layanan. Periksa koneksi lalu coba lagi.';
}

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
