import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { loadHistory } from '../src/features/rotation/store.ts';
import { fixture, bearer } from '../test-support/fixture.js';

// Diminta pengguna 2026-11-28: sambungkan hasil deteksi AI, data obat terkumpul, dan rotasi
// menjadi satu alur yang datanya bisa dipercaya.
async function setup(t, deteksi = [['aphids', 5], ['whitefly', 6]]) {
  const f = await fixture(t);
  const headers = bearer((await f.login('petani')).json().data.access_token);
  await f.db.executeMultiple(`
    INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian) VALUES (1, '2026-09-01', 500, 'aktif');
    INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja) VALUES ('M-01', 250, 'tersedia');
    INSERT INTO pemindahan (id_penyemaian, id_meja, tanggal_pemindahan, jumlah_tanaman) VALUES (1, 1, '2026-09-16', 200);
    INSERT INTO hasil_deteksi (id_pemindahan, id_user, gambar, versi_model, tanggal_deteksi)
      VALUES (1, 1, 'https://res.cloudinary.com/demo/a.jpg', 'm1', '2026-09-30T00:00:00.000Z');
  `);
  for (const [hama, jumlah] of deteksi) {
    await f.db.execute({ sql: 'INSERT INTO deteksi_hama (id_hasil_deteksi, kode_hama, jumlah, confidence_maks) VALUES (1, ?, ?, 0.9)', args: [hama, jumlah] });
  }
  const call = (method, url, payload) => f.app.inject({ method, url, payload, headers });
  const create = (body) => call('POST', '/api/v1/rekomendasi-obat', { id_meja: '1', tingkat: 'berat', ...body });
  const accept = (id, body = {}) => call('POST', `/api/v1/rekomendasi-obat/${id}/terima`, body);
  const katalog = async (bahan) => String((await f.db.execute({
    sql: 'SELECT id_katalog FROM obat_katalog WHERE bahan_aktif = ?', args: [bahan],
  })).rows[0].id_katalog);
  let jenis;
  const item = async (fields) => {
    jenis ??= (await call('POST', '/api/v1/jenis-inventaris', { nama_jenis: 'Obat' })).json().data;
    const res = await call('POST', '/api/v1/inventaris', { id_jenis_inventaris: jenis.id_jenis_inventaris, satuan: 'ml', stok_minimum: null, ...fields });
    assert.equal(res.statusCode, 201, res.body);
    const created = res.json().data;
    const masuk = await call('POST', '/api/v1/stok', { jenis_stok: 'masuk', details: [{ id_inventaris: created.id_inventaris, jumlah: '100', satuan: 'ml' }] });
    assert.equal(masuk.statusCode, 201, masuk.body);
    return created;
  };
  return { ...f, call, create, accept, katalog, item };
}

const check = (res, status, code) => {
  assert.equal(res.statusCode, status, res.body);
  if (code) assert.equal(res.json().error.code, code);
};
const count = async (db, sql) => Number((await db.execute(sql)).rows[0].n);

test('foto yang tidak mendeteksi hama itu tidak boleh menjadi dasar saran', async (t) => {
  const s = await setup(t, [['aphids', 5]]);
  check(await s.create({ hama: 'whitefly', id_hasil_deteksi: '1' }), 422, 'DETECTION_PEST_MISMATCH');
  check(await s.create({ hama: 'aphids', id_hasil_deteksi: '1' }), 201);
});

test('tingkat dari model disimpan terpisah dari tingkat pilihan petani', async (t) => {
  const s = await setup(t, [['aphids', 1]]);
  const res = await s.create({ hama: 'aphids', tingkat: 'berat', id_hasil_deteksi: '1' });
  check(res, 201);
  const d = res.json().data;
  assert.equal(d.tingkat, 'berat');
  assert.equal(d.tingkat_model, 'ringan', '1 kutu daun per foto = ringan menurut ambang');
  assert.match(d.alasan, /diubah petani/);
  const manual = (await s.create({ id_meja: '1', hama: 'whitefly', tingkat: 'sedang' })).json().data;
  assert.equal(manual.tingkat_model, null, 'tanpa foto tidak ada tingkat model');
});

test('ambang tingkat di server sama dengan ambang di aplikasi', async (t) => {
  const s = await setup(t);
  const dart = await readFile(new URL('../../mobile/lib/features/pest/domain/pest_summary.dart', import.meta.url), 'utf8');
  const rows = (await s.db.execute('SELECT kode_hama, ambang_sedang, ambang_berat FROM hama ORDER BY kode_hama')).rows;
  assert.equal(rows.length, 3);
  for (const r of rows) {
    const m = dart.match(new RegExp(`${r.kode_hama}\\('${r.kode_hama}', '[^']+', sedangMin: (\\d+), beratMin: (\\d+)\\)`));
    assert.ok(m, `${r.kode_hama} tidak ditemukan di pest_summary.dart`);
    assert.deepEqual([Number(r.ambang_sedang), Number(r.ambang_berat)], [Number(m[1]), Number(m[2])], r.kode_hama);
  }
});

test('bahan stok tertaut obat ber-MoA lain ditolak; riwayat rotasi tidak tercatat salah', async (t) => {
  const s = await setup(t);
  const rec = (await s.create({ hama: 'aphids', id_hasil_deteksi: '1' })).json().data;
  const lain = rec.obat.kode_moa?.startsWith('4') ? 'Flonikamid' : 'Imidakloprid';
  const barang = await s.item({ id_katalog: await s.katalog(lain) });
  const res = await s.accept(rec.id_rekomendasi, { bahan: [{ id_inventaris: barang.id_inventaris, jumlah: '5', satuan: 'ml' }] });
  check(res, 422, 'MATERIAL_MISMATCH');
  assert.match(res.json().error.message, new RegExp(lain, 'i'));
  assert.equal(await count(s.db, 'SELECT COUNT(*) n FROM perawatan'), 0);
});

test('bahan stok produk lain dengan MoA yang sama boleh dipakai', async (t) => {
  const s = await setup(t);
  const rec = (await s.create({ hama: 'aphids', id_hasil_deteksi: '1' })).json().data;
  assert.equal(rec.obat.kode_moa, '4A', 'saran pertama kutu daun berat pada katalog ini');
  const barang = await s.item({ id_katalog: await s.katalog('Imidakloprid') });
  check(await s.accept(rec.id_rekomendasi, { bahan: [{ id_inventaris: barang.id_inventaris, jumlah: '5', satuan: 'ml' }] }), 200);
});

test('nama merek terdaftar dikenali: bahan lain atau campuran ditolak, merek bahan sama diterima', async (t) => {
  const s = await setup(t);
  const rec = (await s.create({ hama: 'aphids', id_hasil_deteksi: '1' })).json().data;
  assert.equal(rec.obat.kode_moa, '4A');
  const line = (b) => ({ bahan: [{ id_inventaris: b.id_inventaris, jumlah: '5', satuan: 'ml' }] });
  // Alika berisi tiametoksam (4A) dan lamda sihalotrin (3A): semprotannya juga memakai 3A.
  const alika = await s.item({ nama_barang: 'Alika 141/106 ZC' });
  const res = await s.accept(rec.id_rekomendasi, line(alika));
  check(res, 422, 'MATERIAL_MISMATCH');
  assert.match(res.json().error.message, /lamda sihalotrin/i);
  const pegasus = await s.item({ nama_barang: 'pegasus  500 sc' });
  check(await s.accept(rec.id_rekomendasi, line(pegasus)), 422, 'MATERIAL_MISMATCH');
  const confidor = await s.item({ nama_barang: 'Confidor 200 SL' });
  check(await s.accept(rec.id_rekomendasi, line(confidor)), 200);
});

test('bahan yang tidak dikenali (mis. nutrisi) tetap boleh dipotong', async (t) => {
  const s = await setup(t);
  const rec = (await s.create({ hama: 'aphids', id_hasil_deteksi: '1' })).json().data;
  const nutrisi = await s.item({ nama_barang: 'AB Mix Selada' });
  check(await s.accept(rec.id_rekomendasi, { bahan: [{ id_inventaris: nutrisi.id_inventaris, jumlah: '5', satuan: 'ml' }] }), 200);
});

test('satu foto dua hama: obat yang mencakup keduanya dipakai bersama dan dihitung satu semprotan', async (t) => {
  const s = await setup(t);
  const a = (await s.create({ hama: 'aphids', id_hasil_deteksi: '1' })).json().data;
  const b = (await s.create({ hama: 'whitefly', id_hasil_deteksi: '1' })).json().data;
  assert.equal(b.obat.id_katalog, a.obat.id_katalog, 'satu semprotan untuk kedua hama');
  assert.match(b.alasan, /satu semprotan/i);
  check(await s.accept(a.id_rekomendasi), 200);
  check(await s.accept(b.id_rekomendasi), 200);
  const riwayat = await loadHistory(s.db, '1');
  assert.equal(riwayat.length, 1, JSON.stringify(riwayat));
});

test('semprotan bersama tidak memicu batas 2x walau keluarga MoA itu sudah sekali dipakai', async (t) => {
  const s = await setup(t);
  // Semprotan sebelumnya pada meja yang sama: 4A, 29, dan 23 masing-masing sekali.
  for (const [bahan, moa] of [['Imidakloprid', '4A'], ['Flonikamid', '29'], ['Spirotetramat', '23']]) {
    const lama = (await s.create({ hama: 'thrips' })).json().data;
    await s.db.execute({ sql: 'UPDATE rekomendasi_perawatan SET id_katalog = ?, kode_moa = ? WHERE id_rekomendasi = ?', args: [await s.katalog(bahan), moa, lama.id_rekomendasi] });
    check(await s.accept(lama.id_rekomendasi), 200);
  }
  const a = (await s.create({ hama: 'aphids', id_hasil_deteksi: '1' })).json().data;
  assert.equal(a.obat.kode_moa, '9B', 'satu-satunya keluarga kutu daun yang belum dipakai');
  const b = (await s.create({ hama: 'whitefly', id_hasil_deteksi: '1' })).json().data;
  assert.equal(b.obat.id_katalog, a.obat.id_katalog);
  check(await s.accept(a.id_rekomendasi), 200);
  // Bagi kutu kebul, 9B berbagi jatah dengan 4: 4A lama + semprotan ini = 2. Menerima saran kedua
  // dari foto yang sama bukan semprotan ketiga.
  check(await s.accept(b.id_rekomendasi), 200);
});

test('normalisasi nama merek di server sama dengan yang dipakai pembuat data (semua merek)', async (t) => {
  const { kunciMerek, kunciDasar } = await import('../src/features/rotation/material.ts');
  const s = await setup(t);
  const rows = (await s.db.execute('SELECT nama_merek, kunci, kunci_dasar FROM merek_obat')).rows;
  assert.ok(rows.length > 2000, `${rows.length} merek`);
  const beda = rows.filter((r) => kunciMerek(String(r.nama_merek)) !== r.kunci || kunciDasar(String(r.kunci)) !== r.kunci_dasar);
  assert.deepEqual(beda.slice(0, 5), [], `${beda.length} merek dinormalkan berbeda`);
});

test('catatan registrasi di katalog sama dengan ringkasan registri yang disimpan', async (t) => {
  const s = await setup(t);
  const ringkasan = JSON.parse(await readFile(new URL('../../../docs/data/registri/ringkasan-2026-11-28.json', import.meta.url), 'utf8'));
  assert.equal(ringkasan.entri_selada, 0);
  for (const [bahan, perHama] of Object.entries(ringkasan.bahan)) {
    const row = (await s.db.execute({ sql: 'SELECT status_registrasi, catatan_registrasi FROM obat_katalog WHERE bahan_aktif = ?', args: [bahan] })).rows[0];
    assert.ok(row, `${bahan} tidak ada di katalog`);
    const total = Object.values(perHama).reduce((n, v) => n + v.produk, 0);
    assert.equal(row.status_registrasi, total > 0 ? 'tercatat_komoditas_lain' : 'tidak_ditemukan', bahan);
    for (const [hama, v] of Object.entries(perHama)) {
      if (v.produk > 0) assert.match(String(row.catatan_registrasi), new RegExp(`${hama} ${v.produk} produk`), bahan);
    }
  }
});

test('indeks kelas hama di database sama dengan urutan kelas model yang dibawa aplikasi', async (t) => {
  const s = await setup(t);
  const labels = (await readFile(new URL('../../mobile/assets/ml/labels.txt', import.meta.url), 'utf8')).trim().split(/\r?\n/);
  const rows = (await s.db.execute('SELECT kode_hama, indeks_model FROM hama')).rows;
  labels.forEach((kode, i) => {
    assert.equal(Number(rows.find((r) => r.kode_hama === kode)?.indeks_model), i, kode);
  });
});

test('0026: up lalu down mengembalikan skema dan data hama seperti sebelumnya', async () => {
  const { openDatabase } = await import('../src/db/client.js');
  const { loadMigrations, migrate } = await import('../src/db/migrate.js');
  const db = await openDatabase({ url: ':memory:' });
  try {
    const all = await loadMigrations();
    const at = all.findIndex((m) => m.id === '0026_ai_stok_rotasi');
    const snapshot = async () => [
      ...(await db.execute(`SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'
        AND name <> '_schema_migrations' ORDER BY type, name`)).rows.map((r) => `${r.name} ${String(r.sql ?? '').replace(/\s+/g, ' ')}`),
      ...(await db.execute('SELECT kode_hama, indeks_model FROM hama ORDER BY kode_hama')).rows.map((r) => `${r.kode_hama}=${r.indeks_model}`),
    ];
    await migrate(db, all.slice(0, at));
    const before = await snapshot();
    await migrate(db, all.slice(0, at + 1));
    await migrate(db, all.slice(0, at + 1), { direction: 'down', allowDataLoss: true });
    assert.deepEqual(await snapshot(), before);
  } finally {
    db.close();
  }
});

test('semprotan bersama: saran pertama juga menyebutnya, dan stok tidak dipotong dua kali', async (t) => {
  // Diminta pengguna 2026-11-28 (lanjutan): satu semprotan = satu pemakaian stok.
  const s = await setup(t);
  const a = (await s.create({ hama: 'aphids', id_hasil_deteksi: '1' })).json().data;
  const b = (await s.create({ hama: 'whitefly', id_hasil_deteksi: '1' })).json().data;
  assert.equal(b.obat.id_katalog, a.obat.id_katalog);
  const aSekarang = (await s.call('GET', `/api/v1/rekomendasi-obat/${a.id_rekomendasi}`)).json().data;
  assert.match(aSekarang.alasan, /satu semprotan/i, 'saran pertama diperbarui saat saran kedua memakai obat yang sama');
  const barang = await s.item({ id_katalog: a.obat.id_katalog });
  const line = { bahan: [{ id_inventaris: barang.id_inventaris, jumlah: '5', satuan: 'ml' }] };
  check(await s.accept(a.id_rekomendasi, line), 200);
  const dua = await s.accept(b.id_rekomendasi, line);
  check(dua, 409, 'SHARED_SPRAY_STOCK');
  assert.equal(await count(s.db, 'SELECT COUNT(*) n FROM perawatan'), 1, 'penolakan tidak membuat perawatan');
  check(await s.accept(b.id_rekomendasi), 200);
  assert.equal(await count(s.db, "SELECT COUNT(*) n FROM stok WHERE id_perawatan IS NOT NULL AND jenis_stok = 'keluar'"), 1);
});

test('barang bernama bahan aktif (bukan merek) juga dikenali, seperti di data dev "Insektisida Abamectin"', async (t) => {
  // Ditemukan 2026-11-28 pada salinan database dev: nama generik lolos pemeriksaan bahan.
  const s = await setup(t);
  const rec = (await s.create({ hama: 'aphids', id_hasil_deteksi: '1' })).json().data;
  assert.equal(rec.obat.kode_moa, '4A');
  const line = (b) => ({ bahan: [{ id_inventaris: b.id_inventaris, jumlah: '5', satuan: 'ml' }] });
  const res = await s.accept(rec.id_rekomendasi, line(await s.item({ nama_barang: 'Insektisida Abamectin' })));
  check(res, 422, 'MATERIAL_MISMATCH');
  assert.match(res.json().error.message, /abamectin.*MoA 6/i);
  check(await s.accept(rec.id_rekomendasi, line(await s.item({ nama_barang: 'Imidacloprid cair' }))), 200);
});
