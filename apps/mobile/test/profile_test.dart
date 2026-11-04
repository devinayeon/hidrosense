import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/features/accounts/data/models/profile_model.dart';
import 'package:hidrosense_mobile/features/accounts/data/repositories/profile_repository.dart';
import 'package:hidrosense_mobile/features/accounts/presentation/pages/profile_page.dart';
import 'package:hidrosense_mobile/features/accounts/presentation/viewmodels/profile_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _profileUser = SessionUser(
  id: '1',
  name: 'Petani Lama',
  username: 'petani',
  role: 'petani',
  permissions: ['profil:read', 'profil:write'],
);

Map<String, dynamic> _profileJson({
  String nama = 'Petani Lama',
  String? email = 'lama@contoh.id',
  String? telepon = '+62 812-3456',
  String? alamat = 'Kebun Lama',
}) => {
  'id_user': '1',
  'nama': nama,
  'username': 'petani',
  'email': email,
  'no_telepon': telepon,
  'alamat': alamat,
  'status_aktif': 1,
  'role': 'petani',
};

ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      MockClient(handler),
      baseUri: Uri.parse('https://example.test/api/v1'),
    )..setTokens(accessToken: 'access', refreshToken: 'refresh');

class FakeProfileRepository implements ProfileRepository {
  ProfileModel profile = ProfileModel.fromJson(_profileJson());
  Object? loadError;
  Object? saveError;
  String? lastNama;
  String? lastEmail;
  String? lastTelepon;
  String? lastAlamat;

  @override
  Future<ProfileModel> getProfile() async {
    final error = loadError;
    if (error != null) throw error;
    return profile;
  }

  @override
  Future<ProfileModel> updateProfile({
    required String nama,
    String? email,
    String? noTelepon,
    String? alamat,
  }) async {
    final error = saveError;
    if (error != null) throw error;
    lastNama = nama.trim();
    lastEmail = email;
    lastTelepon = noTelepon;
    lastAlamat = alamat;
    String? nullable(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    profile = ProfileModel(
      id: profile.id,
      nama: nama.trim(),
      username: profile.username,
      role: profile.role,
      statusAktif: profile.statusAktif,
      email: nullable(email),
      noTelepon: nullable(noTelepon),
      alamat: nullable(alamat),
    );
    return profile;
  }
}

Widget _page({
  required FakeProfileRepository repository,
  SessionUser user = _profileUser,
}) {
  final api = _api((_) async => throw StateError('Unexpected API request'));
  addTearDown(api.close);
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      sessionProvider.overrideWith(
        (_) => SessionViewModel(api, initialState: SessionState(user: user)),
      ),
      profileRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: const ProfilePage()),
  );
}

void main() {
  group('ProfileRepository', () {
    test('getProfile parses contacts safely', () async {
      final repository = ProfileRepositoryImpl(
        _api((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/profile');
          return http.Response(jsonEncode({'data': _profileJson()}), 200);
        }),
      );

      final profile = await repository.getProfile();
      expect(profile.id, '1');
      expect(profile.nama, 'Petani Lama');
      expect(profile.email, 'lama@contoh.id');
      expect(profile.noTelepon, '+62 812-3456');
      expect(profile.alamat, 'Kebun Lama');
    });

    test('updateProfile sends null to clear empty contact fields', () async {
      final repository = ProfileRepositoryImpl(
        _api((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/v1/profile');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['nama'], 'Petani Baru');
          expect(body.containsKey('email'), isTrue);
          expect(body['email'], isNull);
          expect(body.containsKey('no_telepon'), isTrue);
          expect(body['no_telepon'], isNull);
          expect(body.containsKey('alamat'), isTrue);
          expect(body['alamat'], isNull);
          expect(body.containsKey('username'), isFalse);
          return http.Response(
            jsonEncode({
              'data': _profileJson(
                nama: 'Petani Baru',
                email: null,
                telepon: null,
                alamat: null,
              ),
            }),
            200,
          );
        }),
      );

      final profile = await repository.updateProfile(
        nama: 'Petani Baru',
        email: ' ',
        noTelepon: '',
        alamat: '   ',
      );

      expect(profile.nama, 'Petani Baru');
      expect(profile.email, isNull);
      expect(profile.noTelepon, isNull);
      expect(profile.alamat, isNull);
    });
  });

  group('ProfileViewModel', () {
    test('load and save keep errors in their own channels', () async {
      final repository = FakeProfileRepository();
      final vm = ProfileViewModel(repository);

      expect(await vm.load(), isTrue);
      expect(vm.state.profile?.nama, 'Petani Lama');

      repository.saveError = const ApiException(500, 'FAILED', 'Gagal simpan.');
      expect(await vm.save(nama: 'Petani Baru'), isFalse);
      expect(vm.state.saveError, 'Gagal simpan.');
      expect(vm.state.errorMessage, isNull);
      expect(vm.state.isSaving, isFalse);

      repository.saveError = null;
      expect(
        await vm.save(
          nama: 'Petani Baru',
          email: '',
          noTelepon: '',
          alamat: '',
        ),
        isTrue,
      );
      expect(vm.state.saveError, isNull);
      expect(vm.state.profile?.nama, 'Petani Baru');
      expect(vm.state.profile?.email, isNull);
      expect(repository.lastEmail, isEmpty);
      vm.dispose();
    });

    test('load failure is surfaced as a load error', () async {
      final repository = FakeProfileRepository()
        ..loadError = const ApiException(503, 'OFFLINE', 'Server sibuk.');
      final vm = ProfileViewModel(repository);

      expect(await vm.load(), isFalse);
      expect(vm.state.errorMessage, 'Server sibuk.');
      expect(vm.state.saveError, isNull);
      expect(vm.state.isLoading, isFalse);
      vm.dispose();
    });
  });

  group('ProfilePage', () {
    testWidgets('loads, validates, and saves the profile', (tester) async {
      final repository = FakeProfileRepository();
      await tester.pumpWidget(_page(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Informasi Akun'), findsOneWidget);
      expect(find.text('Petani Lama'), findsOneWidget);
      expect(find.text('petani'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '');
      await tester.ensureVisible(find.text('Simpan Perubahan'));
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();
      expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);

      await tester.enterText(fields.at(0), 'Petani Baru');
      await tester.enterText(fields.at(2), '');
      await tester.enterText(fields.at(3), '');
      await tester.enterText(fields.at(4), '');
      await tester.ensureVisible(find.text('Simpan Perubahan'));
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(repository.lastNama, 'Petani Baru');
      expect(repository.lastEmail, isEmpty);
      expect(repository.lastTelepon, isEmpty);
      expect(repository.lastAlamat, isEmpty);
      expect(find.text('Profil berhasil diperbarui.'), findsOneWidget);
    });

    testWidgets('keeps a save error inside the form', (tester) async {
      final repository = FakeProfileRepository()
        ..saveError = const ApiException(
          409,
          'USERNAME_TAKEN',
          'Data bentrok.',
        );
      await tester.pumpWidget(_page(repository: repository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Simpan Perubahan'));
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(find.text('Data bentrok.'), findsOneWidget);
      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('denies access without profile permissions', (tester) async {
      final repository = FakeProfileRepository();
      await tester.pumpWidget(
        _page(
          repository: repository,
          user: const SessionUser(
            id: '2',
            name: 'Pegawai',
            username: 'pegawai',
            role: 'pegawai',
            permissions: ['inventaris:read'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Akses profil tidak diizinkan.'), findsOneWidget);
      expect(find.text('Informasi Akun'), findsNothing);
    });
  });
}
