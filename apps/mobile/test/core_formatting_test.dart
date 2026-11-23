// Regresi formatAngka: nilai di bawah 0,005 tidak boleh menghasilkan titik
// gantung. Sebelum perbaikan, formatAngka(1.001) mengembalikan "1." (bug QA).
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/formatting.dart';

void main() {
  test('bilangan bulat tanpa desimal', () {
    expect(formatAngka(0), '0');
    expect(formatAngka(50), '50');
    expect(formatAngka(50.0), '50');
  });

  test('desimal satu angka tetap satu angka', () {
    expect(formatAngka(2.5), '2.5');
    expect(formatAngka(0.5), '0.5');
    expect(formatAngka(10.2), '10.2');
  });

  test('desimal dua angka yang berakhir nol dipangkas', () {
    expect(formatAngka(1.10), '1.1');
    expect(formatAngka(2.50), '2.5');
  });

  test('nilai di bawah 0,01 tidak menghasilkan titik gantung', () {
    expect(formatAngka(1.001), isNot(contains('.')));
    expect(formatAngka(1.001), '1');
    expect(formatAngka(0.001), '0');
    expect(formatAngka(9.999), '10');
  });
}
