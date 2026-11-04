import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/services/api_client.dart';
import '../../../../viewmodels/session_viewmodel.dart';
import '../models/profile_model.dart';

abstract class ProfileRepository {
  Future<ProfileModel> getProfile();

  Future<ProfileModel> updateProfile({
    required String nama,
    String? email,
    String? noTelepon,
    String? alamat,
  });
}

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<ProfileModel> getProfile() async {
    return _profile(await _api.get('profile'));
  }

  @override
  Future<ProfileModel> updateProfile({
    required String nama,
    String? email,
    String? noTelepon,
    String? alamat,
  }) async {
    final response = await _api.patch(
      'profile',
      body: {
        'nama': nama.trim(),
        'email': _nullable(email),
        'no_telepon': _nullable(noTelepon),
        'alamat': _nullable(alamat),
      },
    );
    final updated = _profile(response);
    if (updated.nama != nama.trim()) {
      throw const FormatException('Respons profil tidak sesuai isian.');
    }
    return updated;
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  ProfileModel _profile(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons profil tidak valid.');
    }
    return ProfileModel.fromJson(data);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(apiClientProvider));
});
