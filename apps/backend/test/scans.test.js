import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

const env = { CLOUDINARY_CLOUD_NAME: 'democloud', CLOUDINARY_API_KEY: '123456789012345', CLOUDINARY_API_SECRET: 'unit-test-secret' };
const photo = 'https://res.cloudinary.com/democloud/image/upload/v1/hidrosense/pindai/1/a.jpg';

async function setup(t, options = {}) {
  const f = await fixture(t, options);
  const headers = bearer((await f.login('petani')).json().data.access_token);
  await f.db.executeMultiple(`
    INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian) VALUES (2, '2026-09-01', 500, 'aktif');
    INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja) VALUES ('M-01', 250, 'tersedia');
    INSERT INTO pemindahan (id_penyemaian, id_meja, tanggal_pemindahan, jumlah_tanaman) VALUES (1, 1, '2026-09-16', 200);
  `);
  const send = (method, path = '', payload, extra = {}) =>
    f.app.inject({ method, url: `/api/v1/pindaian${path}`, payload, headers: { ...headers, ...extra } });
  const body = (over = {}) => ({
    id_pemindahan: '1', gambar: photo, cloudinary_public_id: 'hidrosense/pindai/1/a', versi_model: 'yolo11n-fp16-cd388bda',
    deteksi: [{ hama: 'aphids', jumlah: 12, confidence_maks: 0.91 }, { hama: 'thrips', jumlah: 3 }], ...over,
  });
  return { ...f, headers, send, body };
}

const check = (res, status, code) => {
  assert.equal(res.statusCode, status, res.body);
  if (code) assert.equal(res.json().error.code, code);
};

test('menyimpan pindaian: satu foto, hitungan per kelas urut indeks model', async (t) => {
  const s = await setup(t, { env });
  const res = await s.send('POST', '', s.body());
  check(res, 201);
  const d = res.json().data;
  assert.equal(d.id_meja, '1');
  assert.equal(d.gambar, photo);
  assert.deepEqual(d.deteksi.map((x) => x.hama), ['thrips', 'aphids'], 'urut indeks model: thrips 0, aphids 2');
  assert.equal(d.deteksi[1].confidence_maks, 0.91);
  assert.equal(d.deteksi[0].confidence_maks, null);
  const rows = (await s.db.execute('SELECT COUNT(*) n FROM hasil_deteksi')).rows;
  assert.equal(Number(rows[0].n), 1, 'satu foto = satu baris, bukan satu per hama');
});

test('foto tanpa hama terdeteksi tetap tersimpan', async (t) => {
  const s = await setup(t, { env });
  const res = await s.send('POST', '', s.body({ deteksi: [] }));
  check(res, 201);
  assert.deepEqual(res.json().data.deteksi, []);
});

test('kirim ulang dengan kunci sama tidak menggandakan', async (t) => {
  const s = await setup(t, { env });
  const key = { 'idempotency-key': '22222222-2222-4222-8222-222222222222' };
  check(await s.send('POST', '', s.body(), key), 201);
  check(await s.send('POST', '', s.body(), key), 200);
  assert.equal(Number((await s.db.execute('SELECT COUNT(*) n FROM hasil_deteksi')).rows[0].n), 1);
});

test('alamat foto hanya dari Cloudinary milik aplikasi (https, host, cloud name)', async (t) => {
  const s = await setup(t, { env });
  for (const gambar of [
    'http://res.cloudinary.com/democloud/a.jpg',
    'https://evil.example/democloud/a.jpg',
    'https://res.cloudinary.com/lain/a.jpg',
    'https://res.cloudinary.com.evil.example/democloud/a.jpg',
    'javascript:alert(1)',
  ]) check(await s.send('POST', '', s.body({ gambar })), 400);
});

test('foto harus berada di folder pindai milik pengguna sendiri', async (t) => {
  const s = await setup(t, { env });
  const other = 'https://res.cloudinary.com/democloud/image/upload/v1/hidrosense/pindai/2/a.jpg';
  check(await s.send('POST', '', s.body({ gambar: other })), 400);
  const outside = 'https://res.cloudinary.com/democloud/image/upload/v1/lain/a.jpg';
  check(await s.send('POST', '', s.body({ gambar: outside })), 400);
  check(await s.send('POST', '', s.body({ cloudinary_public_id: 'hidrosense/pindai/2/a' })), 400);
  const traversal = 'https://res.cloudinary.com/democloud/image/upload/v1/hidrosense/pindai/1/../2/a.jpg';
  check(await s.send('POST', '', s.body({ gambar: traversal })), 400);
  const nested = 'https://res.cloudinary.com/democloud/image/upload/v1/hidrosense/pindai/2/x/hidrosense/pindai/1/a.jpg';
  check(await s.send('POST', '', s.body({ gambar: nested })), 400, 'VALIDATION_ERROR');
  check(await s.send('POST', '', s.body({ gambar: `${photo}?x=1` })), 400);
  check(await s.send('POST', '', s.body({ cloudinary_public_id: 'hidrosense/pindai/1/../2/a' })), 400);
});

test('tanpa konfigurasi Cloudinary: 503, bukan menerima foto dari akun mana pun', async (t) => {
  const s = await setup(t);
  check(await s.send('POST', '', s.body()), 503, 'UPLOAD_NOT_CONFIGURED');
});

test('validasi: hama dobel, hama asing, jumlah nol, field asing, pemindahan tidak ada', async (t) => {
  const s = await setup(t, { env });
  check(await s.send('POST', '', s.body({ deteksi: [{ hama: 'thrips', jumlah: 1 }, { hama: 'thrips', jumlah: 2 }] })), 400);
  check(await s.send('POST', '', s.body({ deteksi: [{ hama: 'tikus', jumlah: 1 }] })), 400);
  check(await s.send('POST', '', s.body({ deteksi: [{ hama: 'thrips', jumlah: 0 }] })), 400);
  check(await s.send('POST', '', s.body({ deteksi: [{ hama: 'thrips', jumlah: 1, confidence_maks: 1.5 }] })), 400);
  check(await s.send('POST', '', { ...s.body(), x: 1 }), 400);
  check(await s.send('POST', '', s.body({ id_pemindahan: '99' })), 422, 'TRANSFER_NOT_FOUND');
});

test('daftar dan detail; filter pemindahan; izin pegawai ditolak', async (t) => {
  const s = await setup(t, { env });
  const id = (await s.send('POST', '', s.body())).json().data.id_hasil_deteksi;
  check(await s.send('GET', `/${id}`), 200);
  check(await s.send('GET', '/999'), 404);
  assert.equal((await s.send('GET', '?id_pemindahan=1')).json().meta.total, 1);
  assert.equal((await s.send('GET', '?id_pemindahan=2')).json().meta.total, 0);
  const h = bearer((await s.login('pegawai')).json().data.access_token);
  check(await s.app.inject({ method: 'GET', url: '/api/v1/pindaian', headers: h }), 403);
  check(await s.app.inject({ method: 'GET', url: '/api/v1/pindaian' }), 401);
});

test('hasil pindai bisa menjadi asal rekomendasi', async (t) => {
  const s = await setup(t, { env });
  const id = (await s.send('POST', '', s.body())).json().data.id_hasil_deteksi;
  const rec = await s.app.inject({
    method: 'POST', url: '/api/v1/rekomendasi-obat', headers: s.headers,
    payload: { id_meja: '1', hama: 'aphids', tingkat: 'sedang', id_hasil_deteksi: id },
  });
  check(rec, 201);
  assert.equal(rec.json().data.id_hasil_deteksi, id);
});

test('database: jumlah deteksi dan hama dijaga constraint', async (t) => {
  const s = await setup(t, { env });
  const id = (await s.send('POST', '', s.body())).json().data.id_hasil_deteksi;
  await assert.rejects(s.db.execute({ sql: "INSERT INTO deteksi_hama VALUES (?, 'thrips', 1, 0.5)", args: [id] }), 'kunci ganda');
  await assert.rejects(s.db.execute({ sql: "INSERT INTO deteksi_hama VALUES (?, 'whitefly', 0, 0.5)", args: [id] }));
  await assert.rejects(s.db.execute({ sql: "INSERT INTO deteksi_hama VALUES (?, 'tikus', 1, 0.5)", args: [id] }));
  await assert.rejects(s.db.execute({ sql: "INSERT INTO hasil_deteksi (id_pemindahan,id_user,gambar,versi_model,tanggal_deteksi) VALUES (1,1,'http://x/a.jpg','m','t')" }));
});
