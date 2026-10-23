import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../viewmodels/session_viewmodel.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';

@immutable
class ProfileState {
  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.saveError,
  });

  final ProfileModel? profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? saveError;

  ProfileState copyWith({
    ProfileModel? profile,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
    );
  }
}

class ProfileViewModel extends StateNotifier<ProfileState> {
  ProfileViewModel(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;

  Future<bool> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repository.getProfile();
      if (!mounted) return false;
      state = state.copyWith(profile: profile, isLoading: false);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: serviceError(error),
      );
      return false;
    }
  }

  Future<bool> save({
    required String nama,
    String? email,
    String? noTelepon,
    String? alamat,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearSaveError: true,
      clearError: true,
    );
    try {
      final profile = await _repository.updateProfile(
        nama: nama,
        email: email,
        noTelepon: noTelepon,
        alamat: alamat,
      );
      if (!mounted) return false;
      state = state.copyWith(profile: profile, isSaving: false);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(isSaving: false, saveError: serviceError(error));
      return false;
    }
  }
}

final profileViewModelProvider =
    StateNotifierProvider.autoDispose<ProfileViewModel, ProfileState>((ref) {
      return ProfileViewModel(ref.watch(profileRepositoryProvider));
    });
