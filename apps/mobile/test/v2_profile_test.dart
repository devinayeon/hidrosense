import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/features/accounts/data/models/profile_model.dart';
import 'package:hidrosense_mobile/features/accounts/data/repositories/profile_repository.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_profile_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_profile_form_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_button.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_dialog.dart';

const _pegawai = ProfileModel(
  id: '2',
  nama: 'Sari Dewi',
  username: 'sari.dewi',
  role: 'pegawai',
  statusAktif: 1,
  noTelepon: '0812 3456 7890',
  alamat: 'Jl. Melati 12, Malang',
);

const _petani = ProfileModel(
  id: '1',
  nama: 'Budi Santoso',
  username: 'budi',
  role: 'petani',
  statusAktif: 1,
);

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile);

  final ProfileModel profile;
  int deactivateCalls = 0;

  @override
  Future<ProfileModel> getProfile() async => profile;

  @override
  Future<ProfileModel> updateProfile({
    required String nama,
    String? username,
    String? password,
    String? currentPassword,
    String? email,
    String? noTelepon,
    String? alamat,
  }) async {
    return ProfileModel(
      id: profile.id,
      nama: nama,
      username: username ?? profile.username,
      role: profile.role,
      statusAktif: profile.statusAktif,
      email: email,
      noTelepon: noTelepon,
      alamat: alamat,
    );
  }

  @override
  Future<void> deactivateSelf() async {
    deactivateCalls++;
  }
}

class _HeldProfileRepository implements ProfileRepository {
  _HeldProfileRepository(this.profile);

  final ProfileModel profile;
  final Completer<ProfileModel> _saved = Completer<ProfileModel>();
  int calls = 0;

  @override
  Future<ProfileModel> getProfile() async => profile;

  @override
  Future<ProfileModel> updateProfile({
    required String nama,
    String? username,
    String? password,
    String? currentPassword,
    String? email,
    String? noTelepon,
    String? alamat,
  }) {
    calls++;
    return _saved.future;
  }

  @override
  Future<void> deactivateSelf() async {}
}

Future<void> _pumpBeranda(WidgetTester tester, V2BerandaRole role) async {
  tester.view.physicalSize = const Size(480, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(home: V2BerandaPage(role: role, onOpenProfile: () {})),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('petani punya menu Akun saya di tab Lainnya', (tester) async {
    await _pumpBeranda(tester, V2BerandaRole.petani);
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();

    expect(find.text('Akun saya'), findsOneWidget);
    expect(find.text('Akun pegawai'), findsOneWidget);
  });

  testWidgets('pegawai punya menu Akun saya di tab Profil', (tester) async {
    await _pumpBeranda(tester, V2BerandaRole.pegawai);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Akun saya'), findsOneWidget);
    expect(find.text('sari.dewi'), findsOneWidget);
    expect(find.text('Akun pegawai'), findsNothing);
    expect(find.text('Penjualan'), findsNothing);
  });

  testWidgets('form profil menolak password baru sama dengan password lama', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: V2ProfileFormPage(initial: _petani)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(2), 'rahasia1');
    await tester.enterText(find.byType(TextField).at(3), 'rahasia1');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Password baru tidak boleh sama dengan password lama'),
      findsOneWidget,
    );
  });

  testWidgets('form profil mewajibkan password saat ini bila username diubah', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: V2ProfileFormPage(initial: _petani)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'budi.baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Isi password saat ini'), findsOneWidget);
  });

  testWidgets('ubah profil: konfirmasi dulu, spinner saat menyimpan', (
    tester,
  ) async {
    final repository = _HeldProfileRepository(_petani);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: V2ProfileFormPage(initial: _petani)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Budi Baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Pop-up konfirmasi muncul dulu; server belum dipanggil.
    expect(find.text('Simpan perubahan profil?'), findsOneWidget);
    expect(repository.calls, 0);
    expect(find.text('Ubah profil'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(V2Dialog),
        matching: find.widgetWithText(V2Button, 'Simpan'),
      ),
    );
    await tester.pump();

    // Spinner tampil di tombol dialog dan form belum kembali.
    expect(repository.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ubah profil'), findsOneWidget);
  });

  testWidgets('ubah profil: batal tidak memanggil server', (tester) async {
    final repository = _HeldProfileRepository(_petani);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: V2ProfileFormPage(initial: _petani)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Budi Baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(repository.calls, 0);
    expect(find.text('Simpan perubahan profil?'), findsNothing);
    expect(find.text('Ubah profil'), findsOneWidget);
  });

  testWidgets('pegawai: Nonaktifkan memanggil server setelah konfirmasi', (
    tester,
  ) async {
    final repository = _FakeProfileRepository(_pegawai);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: V2ProfileDetailPage(profile: _pegawai, canDeactivate: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nonaktifkan'), findsOneWidget);
    await tester.tap(find.text('Nonaktifkan'));
    await tester.pumpAndSettle();
    expect(find.text('Nonaktifkan akun?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(V2Dialog),
        matching: find.widgetWithText(V2Button, 'Nonaktifkan'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.deactivateCalls, 1);
  });

  testWidgets('petani tidak ditawari tombol Nonaktifkan', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: V2ProfileDetailPage(profile: _petani)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nonaktifkan'), findsNothing);
    expect(find.text('Ubah'), findsOneWidget);
  });
}