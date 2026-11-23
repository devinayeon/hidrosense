import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

async function setup(t) {
  const f = await fixture(t);
  const token = (await f.login('petani')).json().data.access_token;
  const headers = bearer(token);
  await f.db.executeMultiple(`
    INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian) VALUES (2, '2026-09-01', 500, 'aktif');
    INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja) VALUES ('M-01', 250, 'tersedia'), ('M-02', 250, 'tersedia');
    INSERT INTO pemindahan (id_penyemaian, id_meja, tanggal_pemindahan, jumlah_tanaman) VALUES (1, 1, '2026-09-16', 200);
    INSERT INTO hasil_deteksi (id_pemindahan, id_user, gambar, versi_model, tanggal_deteksi) VALUES (1, 1, 'https://res.cloudinary.com/demo/a.jpg', 'm1', '2026-09-30T00:00:00.000Z');
  `);
  const send = (method, path = '', payload, extra = {}) =>
    f.app.inject({ method, url: `/api/v1/rekomendasi-obat${path}`, payload, headers: { ...headers, ...extra } });
  const create = (body = {}) =>
    send('POST', '', { id_meja: '1', hama: 'thrips', tingkat: 'sedang', ...body });
  const accept = (id, body = {}) => send('POST', `/${id}/terima`, body);
  const reject = (id, body) => send('POST', `/${id}/tolak`, body);
  return { ...f, headers, send, create, accept, reject };
}

function check(response, status, code) {
  assert.equal(response.statusCode, status, response.body);
  if (code) assert.equal(response.json().error.code, code);
}

test('membuat rekomendasi: 201, status pending, obat dengan MoA dan sumber', async (t) => {
  const s = await setup(t);
  const res = await s.create({ tingkat: 'berat' });
  check(res, 201);
  const { data, replayed } = res.json();
  assert.equal(replayed, false);
  assert.equal(data.status, 'menunggu');
  assert.equal(data.kode_meja, 'M-01');
  assert.equal(data.obat.jenis, 'kimia');
  assert.ok(data.obat.kode_moa);
  assert.ok(data.obat.sumber.length > 0);
  assert.equal(data.obat.terverifikasi, false, 'katalog riset web belum diverifikasi pakar');
  assert.equal(res.headers.location, `/api/v1/rekomendasi-obat/${data.id_rekomendasi}`);
});

test('serangan ringan: nonkimia lebih dulu (PHT)', async (t) => {
  const s = await setup(t);
  const data = (await s.create({ tingkat: 'ringan' })).json().data;
  assert.notEqual(data.obat.jenis, 'kimia');
  assert.equal(data.rule_id, 'ROT-PHT');
});

test('penilaian baru untuk meja dan hama yang sama memperbarui saran yang menunggu, bukan diabaikan', async (t) => {
  const s = await setup(t);
  const first = (await s.create({ tingkat: 'ringan' })).json().data;
  const res = await s.create({ tingkat: 'berat', id_hasil_deteksi: '1' });
  check(res, 200);
  const d = res.json().data;
  assert.equal(d.id_rekomendasi, first.id_rekomendasi, 'tetap satu saran menunggu');
  assert.equal(d.tingkat, 'berat');
  assert.equal(d.id_hasil_deteksi, '1');
  assert.equal(d.obat.jenis, 'kimia', 'dihitung ulang untuk tingkat baru');
  assert.equal(res.json().replayed, false);
  assert.equal((await s.send('GET', '')).json().meta.total, 1);
});

test('penolakan "tidak tersedia" membuat obat itu tidak disarankan lagi; "sudah ditangani" tidak', async (t) => {
  const s = await setup(t);
  const a = (await s.create({ tingkat: 'berat' })).json().data;
  check(await s.reject(a.id_rekomendasi, { alasan: 'tidak_tersedia' }), 200);
  const b = (await s.create({ tingkat: 'berat' })).json().data;
  assert.notEqual(b.obat.id_katalog, a.obat.id_katalog);
  assert.match(b.alasan, /ditolak/);
  check(await s.reject(b.id_rekomendasi, { alasan: 'sudah_ditangani' }), 200);
  const c = (await s.create({ tingkat: 'berat' })).json().data;
  assert.equal(c.obat.id_katalog, b.obat.id_katalog, 'sudah_ditangani bukan masalah obat');
});

test('penolakan "tidak tersedia" kedaluwarsa setelah 30 hari', async (t) => {
  const s = await setup(t);
  const a = (await s.create({ tingkat: 'berat' })).json().data;
  check(await s.reject(a.id_rekomendasi, { alasan: 'tidak_tersedia' }), 200);
  s.advance(31 * 24 * 60 * 60 * 1000);
  const token = (await s.login('petani')).json().data.access_token;
  const res = await s.app.inject({
    method: 'POST', url: '/api/v1/rekomendasi-obat', headers: bearer(token),
    payload: { id_meja: '1', hama: 'thrips', tingkat: 'berat' },
  });
  check(res, 201);
  assert.equal(res.json().data.obat.id_katalog, a.obat.id_katalog);
});

test('terima ulang dengan catatan berbeda ditolak 409, catatan sama aman', async (t) => {
  const s = await setup(t);
  const rec = (await s.create()).json().data;
  check(await s.accept(rec.id_rekomendasi, { catatan: 'Sore' }), 200);
  check(await s.accept(rec.id_rekomendasi, { catatan: 'Sore' }), 200);
  check(await s.accept(rec.id_rekomendasi, { catatan: 'Pagi' }), 409, 'RECOMMENDATION_ALREADY_DECIDED');
});

test('membuat dua kali (ketuk ganda): 200 dan id sama, tidak menumpuk', async (t) => {
  const s = await setup(t);
  const first = (await s.create()).json().data;
  const again = await s.create();
  check(again, 200);
  assert.equal(again.json().replayed, true);
  assert.equal(again.json().data.id_rekomendasi, first.id_rekomendasi);
  const list = (await s.send('GET', '')).json();
  assert.equal(list.meta.total, 1);
});

test('rotasi: MoA dari 2 aplikasi terakhir tidak muncul lagi pada meja yang sama', async (t) => {
  const s = await setup(t);
  const used = [];
  for (let i = 0; i < 3; i += 1) {
    const rec = (await s.create({ tingkat: 'berat' })).json().data;
    assert.ok(!used.slice(-2).includes(rec.obat.kode_moa), `MoA ${rec.obat.kode_moa} berulang dalam jendela ${used.slice(-2)}`);
    check(await s.accept(rec.id_rekomendasi), 200);
    used.push(rec.obat.kode_moa);
    s.advance(1000);
  }
  assert.equal(new Set(used).size, 3);
});

test('riwayat per meja: aplikasi di M-01 tidak memblokir M-02', async (t) => {
  const s = await setup(t);
  const m1 = (await s.create({ tingkat: 'berat' })).json().data;
  check(await s.accept(m1.id_rekomendasi), 200);
  const m2 = (await s.create({ id_meja: '2', tingkat: 'berat' })).json().data;
  assert.equal(m2.obat.kode_moa, m1.obat.kode_moa);
});

test('satu semprotan mengenai semua hama: MoA terpakai pada thrips memblokir whitefly di meja yang sama', async (t) => {
  const s = await setup(t);
  const thrips = (await s.create({ tingkat: 'berat' })).json().data;
  check(await s.accept(thrips.id_rekomendasi), 200);
  const whitefly = (await s.create({ hama: 'whitefly', tingkat: 'berat' })).json().data;
  assert.notEqual(whitefly.obat.kode_moa, thrips.obat.kode_moa);
});

test('menolak tidak memblokir MoA: rekomendasi berikutnya boleh obat yang sama', async (t) => {
  const s = await setup(t);
  const a = (await s.create({ tingkat: 'berat' })).json().data;
  // Alasan yang bukan soal obat: penolakan tidak boleh memblokir MoA maupun obatnya.
  check(await s.reject(a.id_rekomendasi, { alasan: 'tidak_yakin_hama' }), 200);
  const b = (await s.create({ tingkat: 'berat' })).json().data;
  assert.equal(b.obat.id_katalog, a.obat.id_katalog);
  assert.notEqual(b.id_rekomendasi, a.id_rekomendasi);
});

test('menerima: tercatat tanggal aplikasi (bawaan hari ini) dan bisa diulang aman', async (t) => {
  const s = await setup(t);
  const rec = (await s.create()).json().data;
  const ok = await s.accept(rec.id_rekomendasi);
  check(ok, 200);
  assert.equal(ok.json().data.status, 'diterima');
  assert.equal(ok.json().data.tanggal_aplikasi, '2026-09-30');
  const again = await s.accept(rec.id_rekomendasi);
  check(again, 200);
  assert.equal(again.json().replayed, true);
});

test('tanggal aplikasi di masa depan ditolak 400', async (t) => {
  const s = await setup(t);
  const rec = (await s.create()).json().data;
  check(await s.accept(rec.id_rekomendasi, { tanggal_aplikasi: '2026-10-05' }), 400);
});

test('keputusan berlawanan ditolak 409 (diterima lalu ditolak, dan sebaliknya)', async (t) => {
  const s = await setup(t);
  const a = (await s.create()).json().data;
  check(await s.accept(a.id_rekomendasi), 200);
  check(await s.reject(a.id_rekomendasi, { alasan: 'harga' }), 409, 'RECOMMENDATION_ALREADY_DECIDED');
  const b = (await s.create({ id_meja: '2' })).json().data;
  check(await s.reject(b.id_rekomendasi, { alasan: 'harga' }), 200);
  check(await s.accept(b.id_rekomendasi), 409, 'RECOMMENDATION_ALREADY_DECIDED');
});

test('menolak ulang dengan alasan berbeda ditolak 409, alasan sama aman', async (t) => {
  const s = await setup(t);
  const rec = (await s.create()).json().data;
  check(await s.reject(rec.id_rekomendasi, { alasan: 'harga' }), 200);
  const same = await s.reject(rec.id_rekomendasi, { alasan: 'harga' });
  check(same, 200);
  assert.equal(same.json().replayed, true);
  check(await s.reject(rec.id_rekomendasi, { alasan: 'tidak_tersedia' }), 409, 'RECOMMENDATION_ALREADY_DECIDED');
});

test('balapan terima vs tolak: tepat satu menang, yang lain 409', async (t) => {
  const s = await setup(t);
  const rec = (await s.create()).json().data;
  const [a, b] = await Promise.all([
    s.accept(rec.id_rekomendasi),
    s.reject(rec.id_rekomendasi, { alasan: 'harga' }),
  ]);
  assert.deepEqual([a.statusCode, b.statusCode].sort(), [200, 409]);
  const final = (await s.send('GET', `/${rec.id_rekomendasi}`)).json().data;
  assert.equal(final.status, a.statusCode === 200 ? 'diterima' : 'ditolak');
});

test('menolak wajib beralasan terstruktur; "lainnya" wajib catatan', async (t) => {
  const s = await setup(t);
  const rec = (await s.create()).json().data;
  check(await s.reject(rec.id_rekomendasi, {}), 400);
  check(await s.reject(rec.id_rekomendasi, { alasan: 'asal' }), 400);
  check(await s.reject(rec.id_rekomendasi, { alasan: 'lainnya' }), 400);
  check(await s.reject(rec.id_rekomendasi, { alasan: 'lainnya', catatan: '   ' }), 400);
  const ok = await s.reject(rec.id_rekomendasi, { alasan: 'lainnya', catatan: 'Sudah dilepas predator minggu lalu' });
  check(ok, 200);
  assert.equal(ok.json().data.catatan_penolakan, 'Sudah dilepas predator minggu lalu');
});

test('filter daftar: status, meja, hama; status tidak dikenal 400', async (t) => {
  const s = await setup(t);
  const a = (await s.create()).json().data;
  check(await s.accept(a.id_rekomendasi), 200);
  const b = (await s.create({ id_meja: '2', hama: 'aphids' })).json().data;
  check(await s.reject(b.id_rekomendasi, { alasan: 'harga' }), 200);
  await s.create({ id_meja: '2', hama: 'whitefly' });
  const ids = async (q) => (await s.send('GET', q)).json().data.map((r) => r.id_rekomendasi);
  assert.deepEqual(await ids('?status=diterima'), [a.id_rekomendasi]);
  assert.deepEqual(await ids('?status=ditolak'), [b.id_rekomendasi]);
  assert.equal((await ids('?status=menunggu')).length, 1);
  assert.equal((await ids('?id_meja=2')).length, 2);
  assert.deepEqual(await ids('?hama=aphids'), [b.id_rekomendasi]);
  assert.equal((await ids('')).length, 3);
  check(await s.send('GET', '?status=selesai'), 400);
  check(await s.send('GET', '?foo=1'), 400);
});

test('validasi masukan dan referensi', async (t) => {
  const s = await setup(t);
  check(await s.create({ id_meja: '99' }), 422, 'TABLE_NOT_FOUND');
  check(await s.create({ id_hasil_deteksi: '99' }), 422, 'DETECTION_NOT_FOUND');
  check(await s.create({ hama: 'tikus' }), 400);
  check(await s.create({ tingkat: 'parah' }), 400);
  check(await s.create({ extra: 1 }), 400);
  check(await s.send('GET', '/999'), 404, 'RECOMMENDATION_NOT_FOUND');
  check(await s.accept('999'), 404, 'RECOMMENDATION_NOT_FOUND');
  const linked = await s.create({ id_hasil_deteksi: '1' });
  check(linked, 201);
  assert.equal(linked.json().data.id_hasil_deteksi, '1');
});

test('tanpa token 401; tanpa Idempotency-Key pada tulis 400', async (t) => {
  const s = await setup(t);
  check(await s.app.inject({ method: 'GET', url: '/api/v1/rekomendasi-obat' }), 401);
  const res = await s.app.inject({
    method: 'POST', url: '/api/v1/rekomendasi-obat', headers: s.headers,
    payload: { id_meja: '1', hama: 'thrips', tingkat: 'sedang' }, omitIdempotencyKey: true,
  });
  check(res, 400);
});

test('database menolak keadaan tidak konsisten walau service dilewati', async (t) => {
  const s = await setup(t);
  const base = "INSERT INTO rekomendasi_perawatan (id_meja,kode_hama,tingkat,id_katalog,kode_moa,rule_id,alasan,id_user,tanggal_rekomendasi,";
  await assert.rejects(s.db.execute(`${base}status_rekomendasi) VALUES (1,'thrips','sedang',1,NULL,'x','x',1,'t','diterima')`));
  await assert.rejects(s.db.execute(`${base}status_rekomendasi,alasan_penolakan,tanggal_keputusan) VALUES (1,'thrips','sedang',1,NULL,'x','x',1,'t','ditolak','lainnya','t2')`));
  await assert.rejects(s.db.execute(`${base}status_rekomendasi) VALUES (1,'thrips','sedang',1,NULL,'x','x',1,'t','dihapus')`));
  await assert.rejects(s.db.execute(`${base}status_rekomendasi) VALUES (1,'kutu','sedang',1,NULL,'x','x',1,'t','menunggu')`), 'hama harus ada di tabel hama');
});

test('keputusan final dijaga trigger: tidak bisa diubah atau dihapus, perawatan hanya untuk yang diterima', async (t) => {
  const s = await setup(t);
  const a = (await s.create()).json().data;
  await assert.rejects(s.db.execute({ sql: "INSERT INTO perawatan (id_rekomendasi,id_user,tanggal_perawatan) VALUES (?,1,'2026-09-30')", args: [a.id_rekomendasi] }));
  check(await s.accept(a.id_rekomendasi), 200);
  await assert.rejects(s.db.execute({ sql: "UPDATE rekomendasi_perawatan SET status_rekomendasi='ditolak' WHERE id_rekomendasi=?", args: [a.id_rekomendasi] }), /tidak boleh diubah/);
  await assert.rejects(s.db.execute({ sql: 'UPDATE rekomendasi_perawatan SET rule_id=? WHERE id_rekomendasi=?', args: ['z', a.id_rekomendasi] }));
  await assert.rejects(s.db.execute({ sql: 'DELETE FROM rekomendasi_perawatan WHERE id_rekomendasi=?', args: [a.id_rekomendasi] }), /tidak boleh dihapus/);
  await assert.rejects(s.db.execute({ sql: "INSERT INTO perawatan (id_rekomendasi,id_user,tanggal_perawatan) VALUES (?,1,'2026-09-30')", args: [a.id_rekomendasi] }));
  assert.equal(Number((await s.db.execute('SELECT COUNT(*) n FROM perawatan')).rows[0].n), 1);
});

test('menerima membuat perawatan nyata dengan pengguna, tanggal, dan catatan', async (t) => {
  const s = await setup(t);
  const rec = (await s.create()).json().data;
  const ok = await s.accept(rec.id_rekomendasi, { tanggal_aplikasi: '2026-09-28', catatan: 'Semprot sore hari' });
  check(ok, 200);
  assert.equal(ok.json().data.tanggal_aplikasi, '2026-09-28');
  assert.equal(ok.json().data.catatan_perawatan, 'Semprot sore hari');
  const p = (await s.db.execute('SELECT id_user FROM perawatan')).rows;
  assert.equal(p.length, 1);
  assert.equal(Number(p[0].id_user), 1);
});

test('pegawai tidak boleh memakai fitur ini (izin deteksi/rekomendasi hanya petani)', async (t) => {
  const s = await setup(t);
  const h = bearer((await s.login('pegawai')).json().data.access_token);
  check(await s.app.inject({ method: 'GET', url: '/api/v1/rekomendasi-obat', headers: h }), 403);
  check(await s.app.inject({ method: 'POST', url: '/api/v1/rekomendasi-obat', headers: h, payload: { id_meja: '1', hama: 'thrips', tingkat: 'sedang' } }), 403);
});

test('hasil deteksi dari meja lain ditolak 422', async (t) => {
  const s = await setup(t);
  check(await s.create({ id_meja: '2', id_hasil_deteksi: '1' }), 422, 'DETECTION_TABLE_MISMATCH');
});

test('kunci idempotensi sama: hasil tersimpan diulang; isi berbeda dengan kunci sama 409', async (t) => {
  const s = await setup(t);
  const key = { 'idempotency-key': '11111111-1111-4111-8111-111111111111' };
  const body = { id_meja: '1', hama: 'thrips', tingkat: 'sedang' };
  const first = await s.send('POST', '', body, key);
  check(first, 201);
  const again = await s.send('POST', '', body, key);
  check(again, 200);
  assert.equal(again.json().replayed, true);
  assert.equal(again.json().data.id_rekomendasi, first.json().data.id_rekomendasi);
  check(await s.send('POST', '', { ...body, hama: 'aphids' }, key), 409, 'OPERATION_CONFLICT');
  const list = (await s.send('GET', '')).json();
  assert.equal(list.meta.total, 1);
});

test('keputusan yang diulang dengan kunci baru tidak menaikkan versi', async (t) => {
  const s = await setup(t);
  const rec = (await s.create()).json().data;
  const first = await s.accept(rec.id_rekomendasi);
  const again = await s.accept(rec.id_rekomendasi);
  check(again, 200);
  assert.equal(again.json().operation.public_id, first.json().operation.public_id);
  const feed = (await s.app.inject({ method: 'GET', url: '/api/v1/sync/changes', headers: s.headers })).json();
  const mine = feed.data.filter((c) => c.resource_type === 'rekomendasi_perawatan');
  assert.equal(mine.length, 1, JSON.stringify(feed));
  assert.equal(mine[0].domain_id, rec.id_rekomendasi);
});

test('katalog: bahan kimia wajib punya MoA, dan setiap hama punya cukup MoA untuk rotasi', async (t) => {
  const s = await setup(t);
  await assert.rejects(s.db.execute(
    "INSERT INTO obat_katalog (bahan_aktif,jenis,kode_moa,sumber) VALUES ('X','kimia',NULL,'uji')"));
  const rows = (await s.db.execute(`SELECT h.kode_hama AS hama, COUNT(DISTINCT k.kode_moa) AS moa
    FROM katalog_hama h JOIN obat_katalog k USING (id_katalog) WHERE k.jenis = 'kimia' GROUP BY h.kode_hama`)).rows;
  assert.equal(rows.length, 3);
  for (const r of rows) assert.ok(Number(r.moa) >= 3, `${r.hama}: ${r.moa} MoA kimia`);
});

test('masa tunggu panen: kimia yang punya data menyertakan sumbernya; angka tanpa sumber ditolak database', async (t) => {
  const s = await setup(t);
  const rows = (await s.db.execute("SELECT bahan_aktif, phi_hari, phi_sumber FROM obat_katalog WHERE jenis = 'kimia' ORDER BY bahan_aktif")).rows;
  const byName = Object.fromEntries(rows.map((r) => [r.bahan_aktif, r]));
  assert.equal(Number(byName.Spinosad.phi_hari), 1);
  assert.equal(Number(byName.Flonikamid.phi_hari), 0, '0 hari adalah data, bukan kosong');
  for (const r of rows) {
    if (r.phi_hari !== null) assert.match(String(r.phi_sumber), /Label AS/, `${r.bahan_aktif} tanpa sumber`);
  }
  assert.equal(byName['Lambda-sihalotrin'].phi_hari, null, 'tidak ada data: tetap kosong, bukan ditebak');
  await assert.rejects(s.db.execute("UPDATE obat_katalog SET phi_hari = 5, phi_sumber = NULL WHERE bahan_aktif = 'Spinosad'"), /phi_sumber/);
  await assert.rejects(s.db.execute("INSERT INTO obat_katalog (bahan_aktif, jenis, kode_moa, sumber, phi_hari) VALUES ('X', 'kimia', '5', 'uji', 3)"), /phi_sumber/);
  const rec = (await s.create({ tingkat: 'berat' })).json().data;
  assert.ok('phi_sumber' in rec.obat);
});
