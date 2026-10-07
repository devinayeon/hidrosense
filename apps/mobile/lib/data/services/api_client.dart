import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
  @override
  String toString() => message;
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.permissions,
  });
  final String id, name, username, role;
  final List<String> permissions;

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    if (json['id_user'] is! String ||
        json['nama'] is! String ||
        json['username'] is! String ||
        !['petani', 'pegawai'].contains(json['role']) ||
        json['permissions'] is! List ||
        !(json['permissions'] as List).every((p) => p is String)) {
      throw const FormatException('Identitas sesi tidak valid.');
    }
    return SessionUser(
      id: json['id_user'],
      name: json['nama'],
      username: json['username'],
      role: json['role'],
      permissions: List<String>.unmodifiable(json['permissions']),
    );
  }
}

/// Tokens remain in memory; passwords and tokens never enter the local cache.
class ApiClient {
  ApiClient(
    this._client, {
    required this.baseUri,
    this.allowInsecureLocalhost = false,
  });
  final http.Client _client;
  final Uri baseUri;
  final bool allowInsecureLocalhost;
  String? _access, _refresh;
  Future<void>? _refreshing;
  int _generation = 0;
  int get sessionGeneration => _generation;
  void requireSessionGeneration(int generation) {
    if (generation != _generation || _access == null) {
      throw const ApiException(401, 'SESSION_CHANGED', 'Sesi telah berubah.');
    }
  }

  void Function()? onSessionExpired;
  String get serverOrigin => baseUri.toString();

  static bool isLocalOrPrivateHost(String host) {
    if (['localhost', '127.0.0.1', '10.0.2.2', '::1'].contains(host)) {
      return true;
    }
    final privateIp = RegExp(
      r'^(192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})$',
    );
    return privateIp.hasMatch(host);
  }

  void _validateBase() {
    final local = isLocalOrPrivateHost(baseUri.host);
    if (baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        (baseUri.scheme != 'https' &&
            !(allowInsecureLocalhost && local && baseUri.scheme == 'http'))) {
      throw const ApiException(
        0,
        'CONFIGURATION',
        'Alamat layanan belum dikonfigurasi dengan benar.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    _validateBase();
    final root = baseUri.path.replaceFirst(RegExp(r'/$'), '');
    final uri = baseUri.replace(path: '$root/$path', queryParameters: query);
    final request = http.Request(method, uri)..followRedirects = false;
    if (headers != null) request.headers.addAll(headers);
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await (() async {
      return http.Response.fromStream(await _client.send(request));
    })().timeout(const Duration(seconds: 20));
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } on FormatException {
      // A proxy may return HTML. Report its HTTP status without exposing it.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json?['error'];
      throw ApiException(
        response.statusCode,
        error is Map && error['code'] is String ? error['code'] : 'HTTP_ERROR',
        response.statusCode == 429
            ? 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.'
            : error is Map && error['message'] is String
            ? error['message']
            : 'Layanan tidak dapat memenuhi permintaan.',
      );
    }
    if (json == null) {
      throw const FormatException('Respons layanan tidak valid.');
    }
    return json;
  }

  Map<String, dynamic> _data(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons sesi tidak valid.');
    }
    return data;
  }

  void _tokens(Map<String, dynamic> data) {
    if (data['access_token'] is! String ||
        (data['access_token'] as String).isEmpty ||
        data['refresh_token'] is! String ||
        (data['refresh_token'] as String).isEmpty) {
      throw const FormatException('Token sesi tidak valid.');
    }
    _access = data['access_token'];
    _refresh = data['refresh_token'];
  }

  Future<SessionUser> login(String username, String password) async {
    clearSession();
    final generation = _generation;
    final data = _data(
      await _request(
        'POST',
        'auth/login',
        body: {'username': username, 'password': password},
      ),
    );
    if (generation != _generation) {
      throw const ApiException(
        401,
        'SESSION_CHANGED',
        'Sesi telah berubah. Silakan masuk kembali.',
      );
    }
    final user = SessionUser.fromJson(data['user'] as Map<String, dynamic>);
    _tokens(data);
    return user;
  }

  Future<void> _rotate(int generation) async {
    try {
      final data = _data(
        await _request(
          'POST',
          'auth/refresh',
          body: {'refresh_token': _refresh},
        ),
      );
      if (generation != _generation) {
        throw const ApiException(401, 'SESSION_CHANGED', 'Sesi telah berubah.');
      }
      _tokens(data);
    } catch (_) {
      // Rotation is single-use: an uncertain response requires another login.
      if (generation == _generation) {
        clearSession();
        onSessionExpired?.call();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _authRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final generation = _generation;
    final access = _access;
    if (access == null) {
      throw const ApiException(
        401,
        'UNAUTHENTICATED',
        'Silakan masuk kembali.',
      );
    }
    try {
      final response = await _request(
        method,
        path,
        token: access,
        body: body,
        query: query,
        headers: headers,
      );
      if (generation != _generation) {
        throw const ApiException(401, 'SESSION_CHANGED', 'Sesi telah berubah.');
      }
      return response;
    } on ApiException catch (error) {
      if (error.status != 401 || generation != _generation) rethrow;
      // A late 401 may belong to the access token replaced by another request.
      if (access == _access) {
        final rotation = _refreshing ??= _rotate(generation);
        try {
          await rotation;
        } finally {
          if (identical(_refreshing, rotation)) _refreshing = null;
        }
      }
      if (generation != _generation || _access == null) rethrow;
      try {
        final response = await _request(
          method,
          path,
          token: _access,
          body: body,
          query: query,
          headers: headers,
        );
        if (generation != _generation) {
          throw const ApiException(
            401,
            'SESSION_CHANGED',
            'Sesi telah berubah.',
          );
        }
        return response;
      } on ApiException catch (retryError) {
        if (retryError.status == 401 && generation == _generation) {
          clearSession();
          onSessionExpired?.call();
        }
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _authRequest('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) => _authRequest('POST', path, body: body, query: query, headers: headers);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) => _authRequest('PATCH', path, body: body, query: query);

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) => _authRequest('DELETE', path, body: body, query: query);

  Future<void> logout() async {
    final token = _access;
    clearSession();
    if (token != null) await _request('POST', 'auth/logout', token: token);
  }

  void setTokens({required String accessToken, required String refreshToken}) {
    _access = accessToken;
    _refresh = refreshToken;
  }

  void clearSession() {
    _generation++;
    _access = null;
    _refresh = null;
    _refreshing = null;
  }

  void close() {
    clearSession();
    _client.close();
  }
}
