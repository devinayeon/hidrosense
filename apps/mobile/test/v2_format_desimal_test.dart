// Regresi formatAngkaDesimal (dipakai formatKg/formatJutaAkurat): koma desimal
// tidak boleh berdiri sendiri. Sebelum perbaikan, formatAngkaDesimal(1.001)
// mengembalikan "1," (bug QA).
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_data.dart';

void main() {
  test('bulat tanpa koma', () {
    expect(formatAngkaDesimal(5), '5');
    expect(formatAngkaDesimal(5.0), '5');
  });

  test('desimal gaya lokal memakai koma', () {
    expect(formatAngkaDesimal(5.2), '5,2');
    expect(formatAngkaDesimal(5.25), '5,25');
  });

  test('nilai di bawah 0,01 tidak menghasilkan koma gantung', () {
    expect(formatAngkaDesimal(1.001), isNot(endsWith(',')));
    expect(formatAngkaDesimal(1.001), '1');
    expect(formatAngkaDesimal(0.001), '0');
  });

  test('formatKg ikut bersih', () {
    expect(formatKg(1.001), '1 kg');
    expect(formatKg(60.5), '60,5 kg');
  });
}
