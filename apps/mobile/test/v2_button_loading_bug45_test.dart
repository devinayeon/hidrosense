// Regresi BUG-45: tombol simpan yang sedang menyimpan harus memakai keadaan
// loading. Properti `loading` di V2Button menyatukan semua layar supaya tidak
// perlu menulis ternary `V2ButtonState.loading` sendiri-sendiri.
//
// Bukti gagal di kode lama: parameter `loading` belum ada (tidak ter-compile).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_button.dart';

void main() {
  testWidgets('V2Button loading menampilkan spinner dan tidak bisa ditekan', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2Button(
            label: 'Simpan',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(taps, 0, reason: 'tombol loading tidak boleh memicu simpan lagi');
  });
}