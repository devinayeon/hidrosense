// Regresi sesi 14: kapsul status akun harus memakai kata yang sama dengan
// daftar pegawai ("Aktif"/"Nonaktif"), bukan "Aman"/"Kosong". Sebelum
// perbaikan, halaman detail menampilkan "Aman" saat aktif dan "Kosong"
// bergambar minus saat nonaktif.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/features/accounts/data/models/profile_model.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_akun_employee.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_employee_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_profile_detail_page.dart';

const _aktif = V2Employee(
  id: 'sari',
  name: 'Sari Dewi',
  username: 'sari.dewi',
);

const _nonaktif = V2Employee(
  id: 'agus',
  name: 'Agus Salim',
  username: 'agus.s',
  active: false,
);

Future<void> _pumpDetail(WidgetTester tester, V2Employee employee) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: V2EmployeeDetailPage(employee: employee)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('detail pegawai aktif memakai kapsul "Aktif"', (tester) async {
    await _pumpDetail(tester, _aktif);

    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Aman'), findsNothing);
    expect(find.text('Kosong'), findsNothing);
  });

  testWidgets('detail pegawai nonaktif memakai kapsul "Nonaktif"', (
    tester,
  ) async {
    await _pumpDetail(tester, _nonaktif);

    expect(find.text('Nonaktif'), findsOneWidget);
    expect(find.text('Kosong'), findsNothing);
    expect(find.text('Aman'), findsNothing);
  });

  testWidgets('detail profil sendiri memakai kapsul "Aktif"', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: V2ProfileDetailPage(
            profile: ProfileModel(
              id: '2',
              nama: 'Sari Dewi',
              username: 'sari.dewi',
              role: 'pegawai',
              statusAktif: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Aman'), findsNothing);
    expect(find.text('Kosong'), findsNothing);
  });
}