// Regresi aturan akun (keputusan SA Sesi 7, merevisi D-34): password 6–8
// karakter dan wajib memuat huruf **dan** angka, nomor telepon 10–13 angka,
// alamat tidak boleh hanya angka.
//
// Catatan: server memakai `newPasswordSchema` min 6 (validation.ts); batas
// atas server sengaja lebih longgar (128) supaya kontrak lama tetap sah,
// sedangkan klien menegakkan 8. Batas klien yang diuji di sini.
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
const _alamat = 4;

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

  testWidgets('password 9 karakter ditolak "Maksimal 8 karakter"', (
    tester,
  ) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, 'abc123456');
    await _simpan(tester);

    expect(find.text('Maksimal 8 karakter'), findsOneWidget);
  });

  testWidgets('password tanpa angka ditolak kompleksitas', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, 'rahasia');
    await _simpan(tester);

    expect(find.text('Gunakan huruf dan angka'), findsOneWidget);
  });

  testWidgets('password tanpa huruf ditolak kompleksitas', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, '12345678');
    await _simpan(tester);

    expect(find.text('Gunakan huruf dan angka'), findsOneWidget);
  });

  testWidgets('password 6 karakter huruf+angka diterima batas panjangnya', (
    tester,
  ) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, 'abc123');
    // Telepon 3 angka tetap invalid, jadi form tidak ditutup; ini hanya
    // memastikan galat password tidak muncul.
    await _ketik(tester, _telepon, '123');
    await _simpan(tester);

    expect(find.text('Minimal 6 karakter'), findsNothing);
    expect(find.text('Maksimal 8 karakter'), findsNothing);
    expect(find.text('Gunakan huruf dan angka'), findsNothing);
    expect(find.text('Minimal 10 angka'), findsOneWidget);
  });

  testWidgets('telepon kurang dari 10 angka ditolak', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, 'abc123');
    await _ketik(tester, _telepon, '081234567');
    await _simpan(tester);

    expect(find.text('Minimal 10 angka'), findsOneWidget);
  });

  testWidgets('telepon lebih dari 13 angka ditolak', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, 'abc123');
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

  testWidgets('ubah pegawai: password baru huruf+angka diterima', (
    tester,
  ) async {
    await _pump(tester, const V2EmployeeFormPage.edit(_pegawai));
    await _ketik(tester, _password, 'rahasia1');
    await _ketik(tester, _nama, '');
    await _simpan(tester);

    expect(find.text('Minimal 6 karakter'), findsNothing);
    expect(find.text('Maksimal 8 karakter'), findsNothing);
    expect(find.text('Gunakan huruf dan angka'), findsNothing);
  });

  testWidgets('alamat angka saja ditolak', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, 'abc123');
    await _ketik(tester, _alamat, '12345');
    await _simpan(tester);

    expect(find.text('Alamat tidak boleh hanya angka'), findsOneWidget);
  });

  testWidgets('alamat beralamat jelas diterima', (tester) async {
    await _pump(tester, const V2EmployeeFormPage.create());
    await _ketik(tester, _password, 'abc123');
    await _ketik(tester, _alamat, 'Jl. Melati 12, Malang');
    await _simpan(tester);

    expect(find.text('Alamat tidak boleh hanya angka'), findsNothing);
  });
}
