// Regresi aturan isian & hitungan Sesi 7 (keputusan SA):
// - password 6–8 karakter huruf+angka, telepon 10–13 angka, alamat bukan angka saja
// - jumlah benih ≤ 250, jumlah lubang meja ≤ 250
// - estimasi panen dihitung dari tanggal pindah (0 sejak pindah)
// - kode meja berikutnya mengikuti pola kode yang sudah ada
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/validators.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_panen_data.dart';

void main() {
  group('passwordProblem', () {
    test('kosong wajib diisi (tambah) atau boleh kosong (ubah)', () {
      expect(passwordProblem(''), 'Isi password');
      expect(passwordProblem('', optional: true), isNull);
    });

    test('panjang 6–8 saja', () {
      expect(passwordProblem('ab12'), 'Minimal 6 karakter');
      expect(passwordProblem('ab1234567'), 'Maksimal 8 karakter');
      expect(passwordProblem('ab1234'), isNull);
    });

    test('wajib huruf dan angka', () {
      expect(passwordProblem('abcdef'), 'Gunakan huruf dan angka');
      expect(passwordProblem('123456'), 'Gunakan huruf dan angka');
    });
  });

  group('phoneProblem', () {
    test('opsional', () => expect(phoneProblem(''), isNull));
    test('10–13 angka, pemisah diabaikan', () {
      expect(phoneProblem('081234567'), 'Minimal 10 angka');
      expect(phoneProblem('08123456789012'), 'Maksimal 13 angka');
      expect(phoneProblem('0812 3456 7890'), isNull);
      expect(phoneProblem('+62 812-3456-789'), isNull);
    });
    test('huruf ditolak', () {
      expect(phoneProblem('0812abc67890'), 'Nomor telepon tidak valid');
    });
  });

  group('addressProblem', () {
    test('opsional', () => expect(addressProblem(''), isNull));
    test('angka saja ditolak', () {
      expect(addressProblem('12345'), 'Alamat tidak boleh hanya angka');
    });
    test('mengandung huruf diterima', () {
      expect(addressProblem('Jl. Melati 12'), isNull);
    });
  });

  group('jumlah benih & lubang', () {
    test('benih 1–250', () {
      expect(jumlahBenihProblem(''), 'Isi jumlah benih');
      expect(jumlahBenihProblem('0'), 'Jumlah benih harus angka');
      expect(jumlahBenihProblem('251'), 'Maksimal 250 benih');
      expect(jumlahBenihProblem('250'), isNull);
    });
    test('lubang 1–250', () {
      expect(jumlahLubangProblem(''), 'Isi angka lebih dari 0');
      expect(jumlahLubangProblem('0'), 'Isi angka lebih dari 0');
      expect(jumlahLubangProblem('251'), 'Maksimal 250 lubang');
      expect(jumlahLubangProblem('250'), isNull);
    });
  });

  test('estimasi panen dihitung dari tanggal pindah', () {
    expect(v2PerkiraanPanen(DateTime(2026, 1, 6)), DateTime(2026, 2, 20));
    // Tanam terlambat tetap 45 hari sejak pindah, bukan sejak semai.
    expect(v2PerkiraanPanen(DateTime(2026, 11, 30)), DateTime(2027, 1, 14));
  });

  test('kode meja berikutnya mengikuti pola', () {
    expect(v2KodeMejaBerikutnya(const ['A1']), 'A2');
    expect(v2KodeMejaBerikutnya(const ['A1', 'A2', 'A3']), 'A4');
    expect(v2KodeMejaBerikutnya(const ['M-01', 'M-02']), 'M-03');
    expect(v2KodeMejaBerikutnya(const ['A1', 'B1', 'B2']), 'B3');
    expect(v2KodeMejaBerikutnya(const ['tanpa-angka']), isNull);
    expect(v2KodeMejaBerikutnya(const []), isNull);
  });

  group('grafik panen dari riwayat', () {
    V2PanenItem panen(DateTime tanggal, double layak) => V2PanenItem(
      id: 'p-${tanggal.toIso8601String()}',
      tanggal: tanggal,
      meja: 'Meja A1',
      varietas: 'Romaine',
      jumlahTanaman: 10,
      beratTotal: layak,
      beratReject: 0,
    );

    test('kosong tanpa riwayat', () {
      expect(v2GrafikPanenDari(const []), isEmpty);
      expect(v2GrafikPanenKeterangan(const []), 'Belum ada panen tercatat.');
    });

    test('satu tanggal = satu batang, berat dijumlahkan', () {
      final bars = v2GrafikPanenDari([
        panen(DateTime(2026, 11, 6), 100),
        panen(DateTime(2026, 11, 6), 40),
      ]);
      expect(bars.length, 1);
      expect(bars.single.label, '6 Nov');
      expect(bars.single.berat, 140);
    });

    test('maksimal tiga tanggal terakhir, urut menaik', () {
      final bars = v2GrafikPanenDari([
        panen(DateTime(2026, 11, 1), 10),
        panen(DateTime(2026, 11, 4), 20),
        panen(DateTime(2026, 11, 8), 30),
        panen(DateTime(2026, 11, 12), 40),
      ]);
      expect(bars.map((bar) => bar.label), ['4 Nov', '8 Nov', '12 Nov']);
      expect(
        v2GrafikPanenKeterangan(bars),
        'Panen 4 Nov, 8 Nov, 12 Nov: 20, 30, 40 kg.',
      );
    });
  });
}
