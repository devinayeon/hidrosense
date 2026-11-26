import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_profile_form_page.dart';
import 'package:hidrosense_mobile/features/accounts/data/models/profile_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Regresi: tombol proses di form tidak boleh ikut naik saat keyboard terbuka.
/// Bilah aksi dipasang sebagai `Scaffold.bottomNavigationBar`, jadi ia diam di
/// dasar layar sementara isi form mengecil dan tetap bisa digulir.
void main() {
  const profile = ProfileModel(
    id: '1',
    nama: 'Budi Santoso',
    username: 'budi',
    role: 'petani',
    statusAktif: 1,
  );

  Future<void> pumpForm(WidgetTester tester, Widget form) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(form);
    await tester.pumpAndSettle();
  }

  testWidgets('form meja: tombol Simpan diam saat keyboard terbuka', (
    tester,
  ) async {
    await pumpForm(tester, const MaterialApp(home: V2MejaFormPage.create()));

    final before = tester.getRect(find.text('Simpan'));

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final after = tester.getRect(find.text('Simpan'));
    expect(after.top, closeTo(before.top, 0.5));
    expect(after.bottom, closeTo(before.bottom, 0.5));

    // Isi form tetap bisa digulir untuk menjangkau isian di bawah.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Simpan'), findsOneWidget);
  });

  testWidgets('form profil: tombol Simpan diam saat keyboard terbuka', (
    tester,
  ) async {
    await pumpForm(
      tester,
      ProviderScope(
        child: MaterialApp(home: V2ProfileFormPage(initial: profile)),
      ),
    );

    final before = tester.getRect(find.text('Simpan'));

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final after = tester.getRect(find.text('Simpan'));
    expect(after.top, closeTo(before.top, 0.5));
    expect(after.bottom, closeTo(before.bottom, 0.5));
  });
}