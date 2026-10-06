import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_model.dart';

class AccountState {
  final AccountModel? data;
  final bool isLoading;

  const AccountState({this.data, this.isLoading = false});

  AccountState copyWith({AccountModel? data, bool? isLoading}) {
    return AccountState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AccountViewModel extends StateNotifier<AccountState> {
  AccountViewModel() : super(const AccountState()) {
    loadAccountData();
  }

  Future<void> loadAccountData() async {
    state = state.copyWith(isLoading: true);

    // Simulasi penyiapan data akun statis sesuai UI
    const mockUser = AccountModel(
      nama: 'Supriyadi Ahmad',
      peran: 'Petani Utama / Admin',
      username: '@supri_hidro',
      noWhatsApp: '0812-3456-7890',
      idPerkebunan: 'NFT-AMBULU-01',
      statusSinkronisasi:
          'Data lokal disinkronkan ke server pusat hari ini pukul 10:45.',
    );

    state = state.copyWith(data: mockUser, isLoading: false);
  }
}

final accountViewModelProvider =
    StateNotifierProvider.autoDispose<AccountViewModel, AccountState>((ref) {
      return AccountViewModel();
    });
