import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ROTATION_WINDOW, recommendRotation } from '../src/features/rotation/engine.ts';

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

test('jendela rotasi bawaan adalah 2 aplikasi terakhir', () => {
  assert.equal(ROTATION_WINDOW, 2);
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

test('MoA dari 2 aplikasi terakhir tidak boleh dipilih lagi', () => {
  const riwayat = [applied('4', '5', '2026-09-20'), applied('5', '6', '2026-09-10')];
  const r = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat });
  assert.ok(!['5', '6'].includes(r.obat.kode_moa), `dapat MoA ${r.obat.kode_moa}`);
});

test('produk berbeda tetapi MoA sama dengan aplikasi terakhir ditolak (4A vs 4A)', () => {
  const riwayat = [applied('6', '4A', '2026-09-20')];
  const r = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat });
  assert.notEqual(r.obat.id, '7');
  assert.notEqual(r.obat.kode_moa, '4A');
});

test('aplikasi yang lebih tua dari jendela tidak lagi memblokir MoA-nya', () => {
  const riwayat = [
    applied('8', '23', '2026-09-25'),
    applied('5', '6', '2026-09-20'),
    applied('4', '5', '2026-09-01'),
  ];
  const r = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat });
  assert.ok(!['23', '6'].includes(r.obat.kode_moa));
});

test('urutan riwayat masukan tidak memengaruhi hasil', () => {
  const a = [applied('4', '5', '2026-09-01'), applied('5', '6', '2026-09-20'), applied('8', '23', '2026-09-25')];
  const r1 = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat: a });
  const r2 = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat: [...a].reverse() });
  assert.deepEqual(r1, r2);
});

test('semua MoA kimia terblokir: jatuh ke nonkimia, bukan mengulang MoA', () => {
  const kecil = catalog.filter((o) => o.jenis !== 'kimia' || ['4', '5'].includes(o.id));
  const riwayat = [applied('4', '5', '2026-09-20'), applied('5', '6', '2026-09-10')];
  const r = recommendRotation({ tingkat: 'berat', katalog: kecil, riwayat });
  assert.notEqual(r.obat.jenis, 'kimia');
  assert.equal(r.rule_id, 'ROT-FALLBACK');
});

test('katalog kosong menghasilkan null, bukan lemparan', () => {
  assert.equal(recommendRotation({ tingkat: 'sedang', katalog: [], riwayat: [] }), null);
});

test('hasil deterministik: panggilan berulang sama persis', () => {
  const input = { tingkat: 'berat', katalog: catalog, riwayat: [] };
  assert.deepEqual(recommendRotation(input), recommendRotation(input));
});

test('penjelasan menyebut MoA yang dihindari', () => {
  const riwayat = [applied('4', '5', '2026-09-20')];
  const r = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat });
  assert.match(r.alasan, /5/);
});

test('aplikasi di tanggal yang sama diurutkan menurut urutan kejadian (seq), bukan id obat', () => {
  // id '10' < '9' secara teks. Urutan kejadian: 4 (MoA 5), 5 (MoA 6), lalu 8 (MoA 23).
  const riwayat = [
    { id_obat: '4', kode_moa: '5', tanggal: '2026-09-20', seq: 1 },
    { id_obat: '5', kode_moa: '6', tanggal: '2026-09-20', seq: 2 },
    { id_obat: '10', kode_moa: '23', tanggal: '2026-09-20', seq: 3 },
  ];
  const katalog10 = [...catalog, { id: '10', bahan_aktif: 'Spirotetramat', jenis: 'kimia', kode_moa: '23' }];
  const r = recommendRotation({ tingkat: 'berat', katalog: katalog10, riwayat });
  assert.deepEqual(r.moa_dihindari, ['23', '6']);
  assert.equal(r.obat.kode_moa === '5' || r.obat.kode_moa === '4A', true);
});

test('aplikasi nonkimia tanpa MoA tidak memblokir apa pun', () => {
  const riwayat = [applied('1', null, '2026-09-20'), applied('2', null, '2026-09-19')];
  const r = recommendRotation({ tingkat: 'berat', katalog: catalog, riwayat });
  assert.equal(r.obat.jenis, 'kimia');
});
