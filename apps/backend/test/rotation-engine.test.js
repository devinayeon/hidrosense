import assert from 'node:assert/strict';
import { test } from 'node:test';
import { kombinasi } from '../src/features/rotation/combination.ts';
import {
  MAKS_APLIKASI_PER_SIKLUS, SIKLUS_HARI, melampauiJatah, recommendRotation,
} from '../src/features/rotation/engine.ts';

// Katalog uji: thrips punya dua nonkimia dan empat kimia dari empat kelompok MoA berbeda.
const catalog = [
  { id: '1', bahan_aktif: 'Perangkap biru lengket', jenis: 'mekanis', kode_moa: null },
  { id: '2', bahan_aktif: 'Amblyseius swirskii', jenis: 'hayati', kode_moa: null },
  { id: '3', bahan_aktif: 'Azadirachtin', jenis: 'nabati', kode_moa: 'UN' },
  { id: '4', bahan_aktif: 'Spinosad', jenis: 'kimia', kode_moa: '5' },
  { id: '5', bahan_aktif: 'Abamektin', jenis: 'kimia', kode_moa: '6' },
  { id: '6', bahan_aktif: 'Imidakloprid', jenis: 'kimia', kode_moa: '4A' },
  { id: '7', bahan_aktif: 'Asetamiprid', jenis: 'kimia', kode_moa: '4A' },
  { id: '8', bahan_aktif: 'Spirotetramat', jenis: 'kimia', kode_moa: '23' },
];
const applied = (id, kode_moa, tanggal) => ({ id_obat: id, kode_moa, tanggal });

test('aturan tim: siklus 30 hari, paling banyak 2 kali per cara kerja', () => {
  assert.equal(SIKLUS_HARI, 30);
  assert.equal(MAKS_APLIKASI_PER_SIKLUS, 2);
});

test('serangan ringan memilih nonkimia lebih dulu (urutan PHT)', () => {
  const r = recommendRotation({ tingkat: 'ringan', katalog: catalog, riwayat: [] });
  assert.equal(r.obat.jenis, 'mekanis');
  assert.equal(r.rule_id, 'ROT-PHT');
});

test('serangan sedang: hayati/nabati lebih dulu (PHT), bukan cara mekanis dan bukan kimia', () => {
  const r = recommendRotation({ tingkat: 'sedang', katalog: catalog, riwayat: [] });
  assert.equal(r.obat.jenis, 'hayati');
  assert.equal(r.rule_id, 'ROT-PHT');
});

test('serangan sedang tanpa hayati/nabati tersedia: kimia dengan MoA berbeda', () => {
  const kimiaSaja = catalog.filter((o) => o.jenis === 'mekanis' || o.jenis === 'kimia');
  const r = recommendRotation({ tingkat: 'sedang', katalog: kimiaSaja, riwayat: [] });
  assert.equal(r.obat.jenis, 'kimia');
  assert.equal(r.rule_id, 'ROT-MOA');
});

test('serangan berat tanpa riwayat memilih kimia', () => {
  const r = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat: [] });
  assert.equal(r.obat.jenis, 'kimia');
  assert.equal(r.rule_id, 'ROT-MOA');
});

test('obat yang baru ditolak (tidak tersedia/harga) tidak disarankan lagi', () => {
  const first = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat: [] });
  const next = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat: [], dikecualikan: [first.obat.id] });
  assert.notEqual(next.obat.id, first.obat.id);
  assert.match(next.alasan, /ditolak/);
});

test('semua pilihan dikecualikan: tetap memberi saran (fallback), tidak null', () => {
  const r = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat: [], dikecualikan: catalog.map((o) => o.id) });
  assert.ok(r);
  assert.equal(r.rule_id, 'ROT-FALLBACK');
});

const hariIni = '2026-09-30';
const berat = (riwayat, extra = {}) =>
  recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat, hariIni, ...extra });
const hanya = (...ids) => catalog.filter((o) => ids.includes(o.id));

test('cara kerja yang sama boleh dipakai ke-2 kalinya, ke-3 kalinya diblokir', () => {
  const satu = [applied('4', '5', '2026-09-20')];
  assert.equal(berat(satu, { katalog: hanya('4') }).obat.id, '4', '1x: masih ada jatah');
  const dua = [...satu, applied('4', '5', '2026-09-25')];
  assert.equal(berat(dua, { katalog: hanya('4') }), null, '2x: wajib diganti, tidak diulang');
  const r = berat(dua);
  assert.notEqual(r.obat.kode_moa, '5');
  assert.deepEqual(r.moa_dihindari, ['5']);
  assert.match(r.alasan, /wajib diganti/);
});

test('siklus 30 hari: semprotan hari ke-29 masih dihitung, hari ke-30 tidak', () => {
  const lama = (tanggal) => [applied('4', '5', tanggal), applied('4', '5', '2026-09-25')];
  assert.equal(berat(lama('2026-09-01'), { katalog: hanya('4') }), null);
  assert.equal(berat(lama('2026-08-31'), { katalog: hanya('4') }).obat.id, '4');
});

test('produk berbeda dengan MoA sama berbagi satu jatah (4A vs 4A)', () => {
  const riwayat = [applied('6', '4A', '2026-09-20'), applied('7', '4A', '2026-09-25')];
  assert.equal(berat(riwayat, { katalog: hanya('6', '7') }), null);
});

test('subkelompok 4D berbagi jatah dengan 4A', () => {
  const katalog = [{ id: '9', bahan_aktif: 'Flupiradifuron', jenis: 'kimia', kode_moa: '4D' }];
  const riwayat = [applied('6', '4A', '2026-09-20'), applied('6', '4A', '2026-09-25')];
  assert.equal(berat(riwayat, { katalog }), null);
});

test('masih ada jatah pun, cara kerja yang paling jarang dipakai didahulukan', () => {
  const r = berat([applied('6', '4A', '2026-09-20')]);
  assert.notEqual(r.obat.kode_moa, '4A');
});

test('rotasi berurutan: tiap cara kerja maksimal 2x per siklus lalu habis', () => {
  const kimia = hanya('4', '5', '8');
  const riwayat = [];
  for (let i = 0; i < 6; i += 1) {
    const r = berat(riwayat, { katalog: kimia });
    riwayat.push(applied(r.obat.id, r.obat.kode_moa, '2026-09-30'));
  }
  for (const moa of ['5', '6', '23']) assert.equal(riwayat.filter((a) => a.kode_moa === moa).length, 2);
  assert.equal(new Set(riwayat.slice(0, 3).map((a) => a.kode_moa)).size, 3, 'tiga semprotan pertama berbeda');
  assert.equal(berat(riwayat, { katalog: kimia }), null);
});

test('urutan riwayat masukan tidak memengaruhi hasil', () => {
  const a = [applied('4', '5', '2026-09-01'), applied('5', '6', '2026-09-20'), applied('8', '23', '2026-09-25')];
  assert.deepEqual(berat(a), berat([...a].reverse()));
});

test('semua MoA kimia habis: jatuh ke nonkimia, bukan melanggar jatah', () => {
  const kecil = hanya('1', '4');
  const riwayat = [applied('4', '5', '2026-09-20'), applied('4', '5', '2026-09-25')];
  const r = berat(riwayat, { katalog: kecil });
  assert.equal(r.obat.id, '1');
  assert.equal(r.rule_id, 'ROT-FALLBACK');
});

test('jatah saat terima: berlaku juga untuk tanggal pakai yang dimundurkan', () => {
  const riwayat = [applied('4', '5', '2026-09-10'), applied('4', '5', '2026-09-20')];
  assert.equal(melampauiJatah(riwayat, '5', 'thrips', '2026-09-30'), true);
  assert.equal(melampauiJatah(riwayat, '5', 'thrips', '2026-09-01'), true, 'disisipkan sebelum keduanya');
  assert.equal(melampauiJatah(riwayat, '5', 'thrips', '2026-10-10'), false, '30 hari sesudah yang pertama');
  assert.equal(melampauiJatah(riwayat, '6', 'thrips', '2026-09-30'), false);
  assert.equal(melampauiJatah(riwayat, null, 'thrips', '2026-09-30'), false);
});

test('kombinasi menghasilkan C(n, k) himpunan tanpa pengulangan', () => {
  assert.equal(kombinasi([1, 2, 3, 4, 5], 3).length, 10);
  assert.deepEqual(kombinasi([1, 2, 3], 2), [[1, 2], [1, 3], [2, 3]]);
  assert.deepEqual(kombinasi([1], 2), []);
});

test('rencana rotasi: 3 cara kerja berbeda, langkah pertama = saran, dengan sisa jatah', () => {
  const r = berat([applied('4', '5', '2026-09-20')]);
  const { langkah, jumlah_kombinasi } = r.rencana;
  assert.equal(jumlah_kombinasi, 4, 'C(4 keluarga, 3)');
  assert.deepEqual(langkah.map((l) => l.urutan), [1, 2, 3]);
  assert.equal(langkah[0].id_katalog, r.obat.id);
  assert.equal(new Set(langkah.map((l) => l.kode_moa)).size, 3);
  assert.ok(langkah.every((l) => l.sisa_jatah === 2), 'MoA 5 yang sudah terpakai tidak didahulukan');
});

test('kutu kebul: 9B dan kelompok 4 tidak berada dalam satu rencana dan berbagi jatah', () => {
  const katalog = [
    { id: 'a', bahan_aktif: 'Asetamiprid', jenis: 'kimia', kode_moa: '4A' },
    { id: 'b', bahan_aktif: 'Pimetrozin', jenis: 'kimia', kode_moa: '9B' },
    { id: 'c', bahan_aktif: 'Spirotetramat', jenis: 'kimia', kode_moa: '23' },
    { id: 'd', bahan_aktif: 'Flonikamid', jenis: 'kimia', kode_moa: '29' },
  ];
  const r = berat([], { katalog, hama: 'whitefly' });
  const moa = r.rencana.langkah.map((l) => l.kode_moa);
  assert.ok(!(moa.includes('4A') && moa.includes('9B')), moa.join(','));
  const riwayat = [applied('a', '4A', '2026-09-20'), applied('b', '9B', '2026-09-25')];
  assert.deepEqual(berat(riwayat, { katalog, hama: 'whitefly' }).moa_dihindari, ['4', '9B']);
  assert.deepEqual(berat(riwayat, { katalog, hama: 'aphids' }).moa_dihindari, [], 'hanya untuk kutu kebul');
});

test('masa tunggu panen: kimia yang tidak muat atau tanpa data tidak disarankan', () => {
  const katalog = [
    { id: 'a', bahan_aktif: 'Asetamiprid', jenis: 'kimia', kode_moa: '4A', phi_hari: 7 },
    { id: 'b', bahan_aktif: 'Flonikamid', jenis: 'kimia', kode_moa: '29', phi_hari: 0 },
    { id: 'c', bahan_aktif: 'Tanpa data', jenis: 'kimia', kode_moa: '23', phi_hari: null },
  ];
  const r = berat([], { katalog, sisaHariPanen: 3 });
  assert.deepEqual(r.rencana.langkah.map((l) => l.id_katalog), ['b']);
  assert.match(r.alasan, /Panen 3 hari lagi/);
  assert.equal(berat([], { katalog, sisaHariPanen: null }).rencana.langkah.length, 3);
});

test('katalog kosong menghasilkan null, bukan lemparan', () => {
  assert.equal(recommendRotation({ tingkat: 'sedang', katalog: [], riwayat: [] }), null);
});

test('hasil deterministik: panggilan berulang sama persis', () => {
  const input = { tingkat: 'berat', katalog: catalog, riwayat: [] };
  assert.deepEqual(recommendRotation(input), recommendRotation(input));
});

test('penjelasan menyebut MoA yang dihindari', () => {
  const riwayat = [applied('4', '5', '2026-09-20'), applied('4', '5', '2026-09-25')];
  const r = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat });
  assert.match(r.alasan, /5/);
});

test('aplikasi nonkimia tanpa MoA tidak memblokir apa pun', () => {
  const riwayat = [applied('1', null, '2026-09-20'), applied('2', null, '2026-09-19')];
  const r = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat });
  assert.equal(r.obat.jenis, 'kimia');
});

test('obat bersama dari hama lain pada foto yang sama didahulukan, tetapi tidak melangkahi urutan PHT', () => {
  // Diminta pengguna 2026-11-28: satu semprotan untuk beberapa hama pada satu foto.
  const berat = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat: [], hariIni, pendamping: ['8'] });
  assert.equal(berat.obat.id, '8', 'spirotetramat dipakai bersama walau abjadnya bukan yang pertama');
  const ringan = recommendRotation({ tingkat: 'ringan', katalog: catalog, riwayat: [], hariIni, pendamping: ['2'] });
  assert.equal(ringan.obat.jenis, 'mekanis', 'perangkap tetap lebih dulu daripada agen hayati bersama');
  const habis = [applied('8', '23', '2026-09-20'), applied('8', '23', '2026-09-25')];
  const r = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat: habis, hariIni, pendamping: ['8'] });
  assert.notEqual(r.obat.kode_moa, '23', 'jatah 2x tetap berlaku untuk obat bersama');
});
