// Regresi keputusan SA Sesi 7: peran Pegawai tidak boleh melihat jalan menuju
// fitur yang di backend memang ditolak (cuaca, penjualan, kelola akun).
// Sebelumnya detail siklus tetap menampilkan baris cuaca untuk Pegawai sehingga
// mengetuknya berakhir 403.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';

Future<void> _pump(WidgetTester tester, {required V2BerandaRole role}) async {
  tester.view.physicalSize = const Size(480, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(home: V2BerandaPage(role: role, onOpenWeather: () {})),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Pegawai tidak melihat kartu cuaca di Beranda', (tester) async {
    await _pump(tester, role: V2BerandaRole.pegawai);

    expect(find.text('Berawan, 29°C'), findsNothing);
    expect(find.text('Hujan 14.00'), findsNothing);
  });

  testWidgets('Petani tetap melihat kartu cuaca di Beranda', (tester) async {
    await _pump(tester, role: V2BerandaRole.petani);

    expect(find.text('Berawan, 29°C'), findsOneWidget);
  });

  testWidgets('Pegawai: detail siklus tanpa baris cuaca', (tester) async {
    await _pump(tester, role: V2BerandaRole.pegawai);

    await tester.tap(find.text('Meja A2'));
    await tester.pumpAndSettle();

    expect(find.text('Berawan, 29°C'), findsNothing);
    expect(find.text('Cuaca hari ini'), findsNothing);
  });

  testWidgets('Pegawai: tab Profil tidak menawarkan Akun pegawai/Penjualan', (
    tester,
  ) async {
    await _pump(tester, role: V2BerandaRole.pegawai);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Akun pegawai'), findsNothing);
    expect(find.text('Penjualan'), findsNothing);
    // Data akun sendiri tetap terbaca (read-only).
    expect(find.text('sari.dewi'), findsOneWidget);
  });
}