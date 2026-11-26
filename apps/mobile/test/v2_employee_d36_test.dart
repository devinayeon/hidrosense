// Regresi D-36 (keputusan PM 25–26 Nov 2026): pegawai nonaktif harus bisa
// diaktifkan kembali dari halaman detail. Sebelumnya halaman detail hanya
// menampilkan "Ubah" (dan "Nonaktifkan" saat masih aktif), tanpa jalan
// mengaktifkan kembali; store v2 juga belum punya operasi activate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_akun_employee.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_akun_employee_store.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_employee_detail_page.dart';

const _nonaktif = V2Employee(
  id: 'agus',
  name: 'Agus Salim',
  username: 'agus.s',
  active: false,
);

const _aktif = V2Employee(
  id: 'sari',
  name: 'Sari Dewi',
  username: 'sari.dewi',
);

/// Store palsu: mencatat panggilan `activate` dan mengembalikan pegawai aktif.
class _FakeStore implements V2EmployeeStore {
  _FakeStore(this.employee);

  V2Employee employee;
  int activateCalls = 0;
  bool failActivate = false;

  @override
  Future<V2Employee> activate(String id) async {
    activateCalls++;
    if (failActivate) {
      throw const V2EmployeeStoreException('Gagal mengaktifkan akun.');
    }
    employee = employee.copyWith(active: true);
    return employee;
  }

  @override
  Future<List<V2Employee>> list() => throw UnsupportedError('Tidak dipakai.');

  @override
  Future<V2Employee> create(V2EmployeeDraft draft) =>
      throw UnsupportedError('Tidak dipakai.');

  @override
  Future<V2Employee> update(String id, V2EmployeeDraft draft) =>
      throw UnsupportedError('Tidak dipakai.');

  @override
  Future<V2Employee> deactivate(String id) =>
      throw UnsupportedError('Tidak dipakai.');
}

/// Membuka detail lewat tombol dan menyimpan hasil pop-nya.
Future<void> _pumpHost(
  WidgetTester tester,
  V2Employee employee, {
  V2EmployeeStore? store,
  void Function(V2EmployeeResult?)? simpan,
}) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<V2EmployeeResult>(
                V2EmployeeDetailPage.route(employee, store: store),
              );
              simpan?.call(result);
            },
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pegawai nonaktif menampilkan tombol "Aktifkan"', (tester) async {
    await _pumpHost(tester, _nonaktif);

    expect(find.text('Aktifkan'), findsOneWidget);
    expect(find.text('Nonaktifkan'), findsNothing);
  });

  testWidgets('pegawai aktif tetap hanya menampilkan "Nonaktifkan"', (
    tester,
  ) async {
    await _pumpHost(tester, _aktif);

    expect(find.text('Nonaktifkan'), findsOneWidget);
    expect(find.text('Aktifkan'), findsNothing);
  });

  testWidgets('mode pratinjau mengembalikan V2EmployeeActivated(active)', (
    tester,
  ) async {
    V2EmployeeResult? hasil;
    await _pumpHost(tester, _nonaktif, simpan: (r) => hasil = r);

    await tester.tap(find.text('Aktifkan'));
    await tester.pumpAndSettle();

    expect(hasil, isA<V2EmployeeActivated>());
    expect(hasil!.employee.active, isTrue);
  });

  testWidgets('alur nyata memanggil store.activate lalu menutup halaman', (
    tester,
  ) async {
    final store = _FakeStore(_nonaktif);
    V2EmployeeResult? hasil;
    await _pumpHost(tester, _nonaktif, store: store, simpan: (r) => hasil = r);

    await tester.tap(find.text('Aktifkan'));
    await tester.pumpAndSettle();

    expect(store.activateCalls, 1);
    expect(hasil, isA<V2EmployeeActivated>());
    expect(hasil!.employee.active, isTrue);
  });

  testWidgets('store menolak: halaman tetap terbuka dan pesan tampil', (
    tester,
  ) async {
    final store = _FakeStore(_nonaktif)..failActivate = true;
    V2EmployeeResult? hasil;
    await _pumpHost(tester, _nonaktif, store: store, simpan: (r) => hasil = r);

    await tester.tap(find.text('Aktifkan'));
    await tester.pumpAndSettle();

    expect(store.activateCalls, 1);
    expect(hasil, isNull);
    expect(find.text('Gagal mengaktifkan akun.'), findsOneWidget);
    expect(find.text('Aktifkan'), findsOneWidget);
  });
}
