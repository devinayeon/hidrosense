import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

// Diminta pengguna 2026-11-23: rekomendasi yang diterima boleh memotong stok obat (perawatan -> stok).
async function setup(t) {
  const f = await fixture(t);
  const headers = bearer((await f.login('petani')).json().data.access_token);
  await f.db.executeMultiple(`
    INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian) VALUES (1, '2026-09-01', 500, 'aktif');
    INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja) VALUES ('M-01', 250, 'tersedia');
    INSERT INTO pemindahan (id_penyemaian, id_meja, tanggal_pemindahan, jumlah_tanaman) VALUES (1, 1, '2026-09-16', 200);
  `);
  const call = (method, url, payload, extra = {}) =>
    f.app.inject({ method, url, payload, headers: { ...headers, 'idempotency-key': randomUUID(), ...extra } });
  const rec = (await call('POST', '/api/v1/rekomendasi-obat', { id_meja: '1', hama: 'thrips', tingkat: 'berat' })).json().data;
  // Bahan yang dipotong adalah obat yang disarankan; obat lain kini ditolak (MATERIAL_MISMATCH, 2026-11-28).
  const jenis = (await call('POST', '/api/v1/jenis-inventaris', { nama_jenis: 'Obat' })).json().data;
  const item = (await call('POST', '/api/v1/inventaris', {
    id_jenis_inventaris: jenis.id_jenis_inventaris, nama_barang: `${rec.obat.bahan_aktif} 25 SC`, satuan: 'ml', stok_minimum: null,
  })).json().data;
  const stockIn = await call('POST', '/api/v1/stok', {
    jenis_stok: 'masuk', details: [{ id_inventaris: item.id_inventaris, jumlah: '100', satuan: 'ml' }],
  });
  assert.equal(stockIn.statusCode, 201, stockIn.body);
  const balance = async () => (await f.app.inject({
    url: `/api/v1/inventaris/${item.id_inventaris}/saldo`, headers,
  })).json().data;
  const accept = (body, extra) => call('POST', `/api/v1/rekomendasi-obat/${rec.id_rekomendasi}/terima`, body, extra);
  const line = (jumlah = '10', over = {}) => ({ id_inventaris: item.id_inventaris, jumlah, satuan: 'ml', ...over });
  return { ...f, headers, call, item, balance, rec, accept, line };
}

const check = (res, status, code) => {
  assert.equal(res.statusCode, status, res.body);
  if (code) assert.equal(res.json().error.code, code);
};

const count = async (db, sql) => Number((await db.execute(sql)).rows[0].n);

test('terima dengan bahan: stok keluar milik perawatan, saldo turun, bahan tampil di rekomendasi', async (t) => {
  const s = await setup(t);
  const before = await s.balance();
  const res = await s.accept({ bahan: [s.line('10')] });
  check(res, 200);
  const d = res.json().data;
  assert.equal(d.status, 'diterima');
  assert.deepEqual(d.bahan_terpakai, [{ id_inventaris: s.item.id_inventaris, nama_barang: s.item.nama_barang, jumlah: '10', satuan: 'ml' }]);
  const after = await s.balance();
  assert.equal(Number(before.saldo) - Number(after.saldo), 10);
  assert.equal(await count(s.db, "SELECT COUNT(*) n FROM stok WHERE id_perawatan IS NOT NULL AND jenis_stok = 'keluar'"), 1);
});

test('stok kurang: 409 INSUFFICIENT_STOCK, rekomendasi tetap menunggu, tidak ada perawatan atau stok', async (t) => {
  const s = await setup(t);
  check(await s.accept({ bahan: [s.line('101')] }), 409, 'INSUFFICIENT_STOCK');
  const rec = (await s.call('GET', `/api/v1/rekomendasi-obat/${s.rec.id_rekomendasi}`)).json().data;
  assert.equal(rec.status, 'menunggu');
  assert.equal(await count(s.db, 'SELECT COUNT(*) n FROM perawatan'), 0);
  assert.equal(await count(s.db, 'SELECT COUNT(*) n FROM stok WHERE id_perawatan IS NOT NULL'), 0);
  assert.equal(Number((await s.balance()).saldo), 100);
});

test('satuan salah: 422 UNIT_MISMATCH tanpa efek samping', async (t) => {
  const s = await setup(t);
  check(await s.accept({ bahan: [s.line('5', { satuan: 'kg' })] }), 422, 'UNIT_MISMATCH');
  assert.equal(await count(s.db, 'SELECT COUNT(*) n FROM perawatan'), 0);
});

test('tanpa bahan tetap boleh (cara mekanis atau obat di luar inventaris)', async (t) => {
  const s = await setup(t);
  const res = await s.accept({});
  check(res, 200);
  assert.deepEqual(res.json().data.bahan_terpakai, []);
  assert.equal(Number((await s.balance()).saldo), 100);
});

test('ulang dengan bahan sama: tidak memotong dua kali; bahan berbeda: 409', async (t) => {
  const s = await setup(t);
  check(await s.accept({ bahan: [s.line('10')] }), 200);
  const again = await s.accept({ bahan: [s.line('10')] });
  check(again, 200);
  assert.equal(again.json().replayed, true);
  assert.equal(Number((await s.balance()).saldo), 90, 'tidak terpotong dua kali');
  check(await s.accept({ bahan: [s.line('20')] }), 409, 'RECOMMENDATION_ALREADY_DECIDED');
  check(await s.accept({}), 200, undefined);
});

test('kunci idempotensi sama setelah respons hilang: stok tidak terpotong dua kali', async (t) => {
  const s = await setup(t);
  const key = { 'idempotency-key': '33333333-3333-4333-8333-333333333333' };
  check(await s.accept({ bahan: [s.line('10')] }, key), 200);
  check(await s.accept({ bahan: [s.line('10')] }, key), 200);
  assert.equal(Number((await s.balance()).saldo), 90);
});

test('bahan dobel atau terlalu banyak baris ditolak 400', async (t) => {
  const s = await setup(t);
  check(await s.accept({ bahan: [s.line('1'), s.line('2')] }), 400);
  check(await s.accept({ bahan: Array.from({ length: 6 }, () => s.line('1')) }), 400);
  check(await s.accept({ bahan: [] }), 400);
});

test('stok milik perawatan tidak bisa dibalik lewat koreksi stok biasa', async (t) => {
  const s = await setup(t);
  check(await s.accept({ bahan: [s.line('10')] }), 200);
  const id = String((await s.db.execute('SELECT id_stok FROM stok WHERE id_perawatan IS NOT NULL')).rows[0].id_stok);
  const res = await s.call('POST', `/api/v1/stok/${id}/reverse`, { keterangan: 'salah' });
  assert.ok([404, 409].includes(res.statusCode), res.body);
  assert.equal(Number((await s.balance()).saldo), 90);
});

test('daftar riwayat memuat bahan tiap rekomendasi', async (t) => {
  const s = await setup(t);
  check(await s.accept({ bahan: [s.line('10')] }), 200);
  const list = (await s.call('GET', '/api/v1/rekomendasi-obat?status=diterima')).json();
  assert.equal(list.data[0].bahan_terpakai[0].jumlah, '10');
});
