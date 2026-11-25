// Regresi D-34 (keputusan PM 25–26 Nov 2026): password 6–12 karakter dan
// nomor telepon 10–13 angka. Sebelumnya form menuntut password minimal 12
// karakter tanpa batas atas dan membiarkan telepon apa saja; uji ini memaku
// batas baru supaya tidak kembali longgar (mis. telepon "123") atau kembali
// terlalu ketat (mis. menolak password 6 karakter).
//
// Catatan: server masih memakai `newPasswordSchema` min 12 (validation.ts:42),
// jadi password 6–11 karakter hanya lolos di klien. Batas klien tetap diuji
// sesuai keputusan PM.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_akun_employee.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_employee_form_page.dart';

const _pegawai = V2Employee(
  id: 'sari',
  name: 'Sari Dewi',
  username: 'sari.dewi',
  phone: '0812 3456 7890',
);

/// Indeks TextField tetap: 0 nama, 1 username, 2 password, 3 telepon, 4 alamat.
const _nama = 0;
const _password = 2;
const _telepon = 3;

Future<void> _pump(WidgetTester tester, Widget form) async {
  tester.view.physicalSize = const Size(420, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: form));
  await tester.pumpAndSettle();
}

Future<void> _ketik(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.byType(TextField).at(index), text);
}

Future<void> _simpan(WidgetTester tester) async {
  await tester.tap(find.text('Simpan'));
  await tester.pump();
}

void main() {
  testWidgets('password 5 karakter ditolak "Minimal 6 karakter"', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, '12345');
    await _simpan(tester);

    expect(find.text('Minimal 6 karakter'), findsOneWidget);
  });

  testWidgets('password 13 karakter ditolak "Maksimal 12 karakter"', (
    tester,
  ) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, '1234567890123');
    await _simpan(tester);

    expect(find.text('Maksimal 12 karakter'), findsOneWidget);
  });

  testWidgets('password 6 karakter diterima batas panjangnya', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, '123456');
    // Telepon 3 angka tetap invalid, jadi form tidak ditutup; ini hanya
    // memastikan galat password tidak muncul.
    await _ketik(tester, _telepon, '123');
    await _simpan(tester);

    expect(find.text('Minimal 6 karakter'), findsNothing);
    expect(find.text('Maksimal 12 karakter'), findsNothing);
    expect(find.text('Minimal 10 angka'), findsOneWidget);
  });

  testWidgets('telepon kurang dari 10 angka ditolak', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, '123456');
    await _ketik(tester, _telepon, '081234567');
    await _simpan(tester);

    expect(find.text('Minimal 10 angka'), findsOneWidget);
  });

  testWidgets('telepon lebih dari 13 angka ditolak', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, '123456');
    await _ketik(tester, _telepon, '08123456789012');
    await _simpan(tester);

    expect(find.text('Maksimal 13 angka'), findsOneWidget);
  });

  testWidgets('telepon 12 angka berspasi diterima', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _telepon, '0812 3456 7890');
    await _simpan(tester);

    expect(find.text('Minimal 10 angka'), findsNothing);
    expect(find.text('Maksimal 13 angka'), findsNothing);
    expect(find.text('Nomor telepon tidak valid'), findsNothing);
  });

  testWidgets('telepon berhuruf ditolak', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _telepon, '0812abc67890');
    await _simpan(tester);

    expect(find.text('Nomor telepon tidak valid'), findsOneWidget);
  });

  testWidgets('ubah pegawai: password kosong tetap diperbolehkan', (
    tester,
  ) async {
    await _pump(tester, const V2EmployeeFormPage.edit(_pegawai));
    // Kosongkan nama supaya form tidak ditutup setelah validasi lolos; yang
    // diuji hanya bahwa password kosong tidak dianggap galat di mode ubah.
    await _ketik(tester, _nama, '');
    await _simpan(tester);

    expect(find.text('Minimal 6 karakter'), findsNothing);
    expect(find.text('Isi password'), findsNothing);
    expect(find.text('Isi nama'), findsOneWidget);
  });

  testWidgets('ubah pegawai: password baru 7 karakter diterima', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.edit(_pegawai));
    await _ketik(tester, _password, 'rahasia');
    await _ketik(tester, _nama, '');
    await _simpan(tester);

    expect(find.text('Minimal 6 karakter'), findsNothing);
    expect(find.text('Maksimal 12 karakter'), findsNothing);
  });
}
