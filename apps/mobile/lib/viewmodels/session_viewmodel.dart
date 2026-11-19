import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../data/services/api_client.dart';
import '../data/services/session_store.dart';

export '../data/services/api_client.dart' show SessionUser;

Uri resolveApiBaseUri([String? customAddress]) {
  final raw = (customAddress ?? const String.fromEnvironment('API_BASE_URL'))
      .trim();
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
          path: pathWithoutSlash.isEmpty
              ? '/api/v1'
              : '$pathWithoutSlash/api/v1',
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

/// Kenapa masuk gagal, dalam bentuk yang bisa dipetakan ke layar alur v2.
enum SessionFailure {
  /// Username/password ditolak layanan (401 `INVALID_CREDENTIALS`).
  invalidCredentials,

  /// Password benar tetapi akun dinonaktifkan (403 `ACCOUNT_DEACTIVATED`).
  accountDeactivated,

  /// Request tidak sampai ke layanan (tanpa jaringan / timeout).
  offline,

  /// Layar lain yang bukan dua hal di atas (mis. kuota permintaan).
  service,
}

class SessionState {
  const SessionState({this.user, this.busy = false, this.error, this.failure});
  final SessionUser? user;
  final bool busy;
  final String? error;

  /// Kategori [error] supaya pemanggil tidak perlu membaca teksnya.
  final SessionFailure? failure;
}

String serviceError(Object error) {
  if (kDebugMode) {
    debugPrint('[SessionViewModel] Request error: $error');
  }
  if (error is ApiException) return _friendlyApiMessage(error);
  return error is FormatException
      ? 'Data layanan tidak sesuai. Coba lagi.'
      : 'Tidak dapat menghubungi layanan. Periksa koneksi lalu coba lagi.';
}

/// Mengganti pesan layanan yang memakai istilah teknis dengan kalimat yang
/// bisa ditindaklanjuti pengguna.
///
/// Backend memakai satu kalimat "Input tidak sesuai kontrak API." untuk semua
/// kegagalan validasi tanpa menyebut field mana. Aplikasi tetap memvalidasi
/// isian penting lebih dulu (mis. batas jumlah lubang meja); pesan ini hanya
/// jaring pengaman untuk isian lain yang belum tercakup.
String _friendlyApiMessage(ApiException error) {
  if (error.code == 'VALIDATION_ERROR') {
    final message = error.message.toLowerCase();
    if (message.contains('kontrak api') || message.contains('body json')) {
      return 'Ada isian yang belum sesuai. Periksa kembali data yang Anda masukkan.';
    }
    if (message.contains('header sinkronisasi')) {
      return 'Sinkronisasi data gagal. Coba lagi sebentar.';
    }
  }
  return error.message;
}

SessionFailure classifyFailure(Object error) {
  if (error is FormatException) return SessionFailure.service;
  if (error is! ApiException) return SessionFailure.offline;
  return switch (error.code) {
    'INVALID_CREDENTIALS' ||
    'UNAUTHENTICATED' => SessionFailure.invalidCredentials,
    'ACCOUNT_DEACTIVATED' => SessionFailure.accountDeactivated,
    'CONFIGURATION' => SessionFailure.offline,
    _ => SessionFailure.service,
  };
}

class SessionViewModel extends StateNotifier<SessionState> {
  SessionViewModel(
    this._api, {
    SessionState? initialState,
    Future<SessionStore?> Function()? openStore,
  }) : _openStore = openStore ?? SessionStore.open,
       super(initialState ?? const SessionState()) {
    _api.onSessionExpired = () {
      if (!mounted) return;
      state = const SessionState(error: 'Sesi berakhir. Masuk kembali.');
      unawaited(_clearStore());
    };
  }
  final ApiClient _api;
  final Future<SessionStore?> Function() _openStore;
  Future<SessionStore?>? _store;
  int _operation = 0;

  /// Membuka penyimpanan sekali per proses, lalu dipakai ulang.
  Future<SessionStore?> _open() => _store ??= _openStore();

  Future<void> _persist(SessionUser user) async {
    final store = await _open();
    final access = _api.accessToken, refresh = _api.refreshToken;
    final expiry = _api.refreshExpiresAt;
    if (store == null || access == null || refresh == null || expiry == null) {
      return;
    }
    await store.save(
      serverOrigin: _api.serverOrigin,
      session: StoredSession(
        accessToken: access,
        refreshToken: refresh,
        refreshExpiresAt: expiry,
        user: user,
      ),
    );
  }

  Future<void> _clearStore() async {
    final store = await _open();
    await store?.clear(serverOrigin: _api.serverOrigin);
  }

  /// Memakai sesi tersimpan kalau masa berlakunya belum habis.
  ///
  /// Dipanggil sebelum layar pertama digambar. Bagian lokalnya ditunggu supaya
  /// aplikasi bisa langsung membuka beranda; verifikasi ke layanan lanjut di
  /// latar (`auth/me`) dan hanya menendang keluar kalau token benar-benar
  /// ditolak. Gangguan jaringan tidak membatalkan sesi lokal.
  Future<bool> restore() async {
    final store = await _open();
    if (store == null) return false;
    StoredSession? stored;
    try {
      stored = await store.read(serverOrigin: _api.serverOrigin);
    } catch (_) {
      return false;
    }
    if (stored == null) return false;
    if (stored.expired) {
      await _clearStore();
      return false;
    }
    _api.setTokens(
      accessToken: stored.accessToken,
      refreshToken: stored.refreshToken,
      accessExpiresAt: null,
      refreshExpiresAt: stored.refreshExpiresAt,
    );
    final operation = ++_operation;
    state = SessionState(user: stored.user);
    unawaited(_verify(operation));
    return true;
  }

  Future<void> _verify(int operation) async {
    try {
      final user = await _api.me();
      if (!mounted || operation != _operation) return;
      state = SessionState(user: user);
      await _persist(user);
    } on ApiException catch (error) {
      if (!mounted || operation != _operation) return;
      if (error.status != 401) return;
      // Token ditolak walau masa berlakunya belum habis: sesi benar-benar mati.
      _api.clearSession();
      await _clearStore();
      if (!mounted || operation != _operation) return;
      state = const SessionState(error: 'Sesi berakhir. Masuk kembali.');
    } catch (_) {
      // Tidak bisa memverifikasi (mis. offline); sesi lokal tetap dipakai.
    }
  }

  Future<void> login(String username, String password) async {
    if (state.busy) return;
    final operation = ++_operation;
    state = const SessionState(busy: true);
    try {
      final user = await _api.login(username, password);
      if (mounted && operation == _operation) {
        state = SessionState(user: user);
        await _persist(user);
      }
    } catch (error) {
      if (mounted && operation == _operation) {
        state = SessionState(
          error: serviceError(error),
          failure: classifyFailure(error),
        );
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
    } finally {
      await _clearStore();
    }
  }

  /// Menyelaraskan nama/username tampilan setelah profil sendiri diperbarui.
  void updateIdentity({required String name, required String username}) {
    final user = state.user;
    if (user == null) return;
    state = SessionState(
      user: SessionUser(
        id: user.id,
        name: name,
        username: username,
        role: user.role,
        permissions: user.permissions,
      ),
      busy: state.busy,
      error: state.error,
      failure: state.failure,
    );
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
