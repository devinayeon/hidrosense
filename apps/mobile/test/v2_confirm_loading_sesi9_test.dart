// Sesi 9: setiap tombol proses memakai pop-up konfirmasi ulang yang tombolnya
// menampilkan spinner sampai proses selesai, jadi layar tidak kembali ke menu
// sebelum backend menjawab. Uji ini memaku perilaku inti `showV2ActionDialog`
// dan satu alur nyata (tambah pegawai) yang memakainya.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_akun_employee.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_akun_employee_store.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_employee_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_form_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_dialog.dart';

/// Store yang menahan jawaban supaya keadaan "sedang menyimpan" bisa diperiksa.
class _SlowStore implements V2EmployeeStore {
  final Completer<V2Employee> completer = Completer<V2Employee>();
  V2EmployeeDraft? created;

  @override
  Future<V2Employee> create(V2EmployeeDraft draft) {
    created = draft;
    return completer.future;
  }

  @override
  Future<List<V2Employee>> list() => throw UnsupportedError('Tidak dipakai.');

  @override
  Future<V2Employee> update(String id, V2EmployeeDraft draft) =>
      throw UnsupportedError('Tidak dipakai.');

  @override
  Future<V2Employee> deactivate(String id) =>
      throw UnsupportedError('Tidak dipakai.');

  @override
  Future<V2Employee> activate(String id) =>
      throw UnsupportedError('Tidak dipakai.');
}

Future<void> _pumpDialogHost(
  WidgetTester tester,
  Future<void> Function(BuildContext context) onPressed,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onPressed(context),
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'showV2ActionDialog menahan layar dan menampilkan spinner sampai selesai',
    (tester) async {
      final completer = Completer<void>();
      bool? result;
      var selesai = false;
      await _pumpDialogHost(tester, (context) async {
        result = await showV2ActionDialog(
          context,
          title: 'Simpan perubahan?',
          body: 'Perubahan akan dikirim ke server.',
          primaryLabel: 'Simpan',
          onConfirm: () => completer.future,
        );
        selesai = true;
      });

      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text('Simpan perubahan?'), findsOneWidget);

      // Tekan tombol konfirmasi; proses belum selesai.
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(selesai, isFalse, reason: 'belum boleh kembali sebelum selesai');

      // Menyentuh barrier tidak menutup dialog selama proses berjalan.
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Simpan perubahan?'), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(selesai, isTrue);
      expect(find.text('Simpan perubahan?'), findsNothing);
    },
  );

  testWidgets('showV2ActionDialog melempar galat ke pemanggil', (tester) async {
    Object? tertangkap;
    var selesai = false;
    await _pumpDialogHost(tester, (context) async {
      try {
        await showV2ActionDialog(
          context,
          title: 'Hapus?',
          primaryLabel: 'Hapus',
          onConfirm: () async => throw StateError('server menolak'),
        );
      } catch (error) {
        tertangkap = error;
      }
      selesai = true;
    });

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(tertangkap, isA<StateError>());
    expect(selesai, isTrue);
    expect(find.text('Hapus?'), findsNothing);
  });

  testWidgets('tambah pegawai: loading di pop-up, form baru menutup setelah selesai', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = _SlowStore();
    V2Employee? hasil;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                hasil = await Navigator.of(context).push<V2Employee>(
                  MaterialPageRoute<V2Employee>(
                    builder: (_) => V2EmployeeFormPage.create(store: store),
                  ),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Budi Santoso');
    await tester.enterText(find.byType(TextField).at(1), 'budi.s');
    await tester.enterText(find.byType(TextField).at(2), 'abc123');
    await tester.enterText(find.byType(TextField).at(3), '0812345678');
    await tester.enterText(find.byType(TextField).at(4), 'Jl. Mawar 1');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Pop-up konfirmasi ulang muncul.
    expect(find.text('Tambah pegawai?'), findsOneWidget);

    await tester.tap(find.text('Tambah'));
    await tester.pump();
    expect(store.created, isNotNull, reason: 'tulis dimulai setelah konfirmasi');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.text('Tambah pegawai'),
      findsOneWidget,
      reason: 'form belum menutup sebelum proses selesai',
    );

    store.completer.complete(
      const V2Employee(id: 'budi', name: 'Budi Santoso', username: 'budi.s'),
    );
    await tester.pumpAndSettle();

    expect(hasil, isNotNull);
    expect(hasil!.id, 'budi');
    expect(find.text('Tambah pegawai'), findsNothing);
  });

  testWidgets(
    'form meja: tombol Simpan mengirim lewat pop-up konfirmasi lalu menutup',
    (tester) async {
      V2MejaItem? terkirim;
      V2MejaItem? hasil;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  hasil = await Navigator.of(context).push<V2MejaItem>(
                    V2MejaFormPage.route(
                      onSubmit: (meja) async => terkirim = meja,
                    ),
                  );
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'B1');
      await tester.enterText(find.byType(TextField).at(1), '100');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah meja?'), findsOneWidget);
      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      expect(terkirim, isNotNull, reason: 'onSubmit dipanggil dari pop-up');
      expect(terkirim!.kode, 'B1');
      expect(hasil, isNotNull);
      expect(hasil!.kode, 'B1');
    },
  );
}
