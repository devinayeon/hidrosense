// B11 / PB-05: the device runs YOLO locally; the server records the result against a batch.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { bearer, fixture } from '../test-support/fixture.js';

const image = { public_id: 'hidrosense/scan-1', url: 'https://res.cloudinary.com/demo/image/upload/v1/hidrosense/scan-1.jpg' };

async function setup(t) {
  const f = await fixture(t);
  const headers = bearer((await f.login('petani')).json().data.access_token);
  const pegawai = bearer((await f.login('pegawai')).json().data.access_token);
  await f.db.executeMultiple(`
    INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih) VALUES(1,'2026-09-01',100);
    INSERT INTO meja_tanam(kode_meja,jumlah_lubang) VALUES('M1',100);
    INSERT INTO pemindahan(id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES(1,1,'2026-09-16',50),(1,1,'2026-09-17',50);
  `);
  const body = (overrides = {}) => ({
    id_pemindahan: '1', tanggal_deteksi: '2026-09-29T02:00:00+07:00', status_deteksi: 'terdeteksi', model_versi: 'yolo11n-1',
    ambang_confidence: '0.25', hasil: [{ nama_hama: 'thrips', confidence: '0.9123', jumlah_objek: 3 }], ...overrides,
  });
  const send = (method, url = '', payload, extra = {}, options = {}) => f.app.inject({ method, url: `/api/v1/deteksi${url}`, payload, headers: { ...headers, ...extra }, ...options });
  return { ...f, headers, pegawai, body, send, post: (payload, extra, options) => send('POST', '', payload, extra, options) };
}

function check(response, status, code) {
  assert.equal(response.statusCode, status, response.body);
  if (code) assert.equal(response.json().error.code, code, response.body);
}

test('a detection is stored against its batch with exact values', async (t) => {
  const { post, send, body } = await setup(t);
  const created = await post(body({ gambar: image, keterangan: ' daun bawah ' }));
  check(created, 201);
  assert.equal(created.headers.location, '/api/v1/deteksi/1');
  const { data } = created.json();
  assert.equal(data.id_pemindahan, '1');
  assert.equal(data.id_user, '1');
  assert.equal(data.tanggal_deteksi, '2026-09-28T19:00:00.000Z');
  assert.equal(data.status_deteksi, 'terdeteksi');
  assert.equal(data.model_versi, 'yolo11n-1');
  assert.equal(data.ambang_confidence, '0.2500');
  assert.deepEqual(data.gambar, image);
  assert.equal(data.keterangan, 'daun bawah');
  assert.equal(data.version, '1');
  assert.ok(data.public_id);
  assert.deepEqual(data.hasil.map(({ nama_hama, confidence, jumlah_objek }) => [nama_hama, confidence, jumlah_objek]), [['thrips', '0.9123', 3]]);
  assert.deepEqual((await send('GET', '/1')).json().data, data);
});

test('several pests in one image become one detection with several results', async (t) => {
  const { post, body } = await setup(t);
  const created = await post(body({ hasil: [{ nama_hama: 'aphids', confidence: '1' }, { nama_hama: 'whitefly', confidence: '0.3' }] }));
  check(created, 201);
  assert.deepEqual(created.json().data.hasil.map((row) => [row.nama_hama, row.confidence, row.jumlah_objek]), [['aphids', '1.0000', 1], ['whitefly', '0.3000', 1]]);
  check(await post(body({ hasil: [{ nama_hama: 'aphids', confidence: '0.5' }, { nama_hama: 'aphids', confidence: '0.6' }] })), 400);
});

test('no detection and failed inference are recorded without claiming the plant is pest free', async (t) => {
  const { post, body } = await setup(t);
  for (const status of ['tanpa_deteksi', 'gagal']) {
    const created = await post(body({ status_deteksi: status, hasil: [] }));
    check(created, 201);
    assert.equal(created.json().data.status_deteksi, status);
    assert.deepEqual(created.json().data.hasil, []);
    assert.doesNotMatch(created.body, /bebas|sehat|aman/i);
  }
  check(await post(body({ status_deteksi: 'tanpa_deteksi' })), 400);
  check(await post(body({ hasil: [] })), 400);
});

test('invalid detection input is refused', async (t) => {
  const { post, body } = await setup(t);
  const line = (overrides) => [{ nama_hama: 'thrips', confidence: '0.9', ...overrides }];
  for (const bad of [
    { hasil: line({ nama_hama: 'ulat' }) },
    { hasil: line({ confidence: '1.0001' }) },
    { hasil: line({ confidence: '-0.1' }) },
    { hasil: line({ confidence: '0.12345' }) },
    { hasil: line({ confidence: 0.9 }) },
    { hasil: line({ jumlah_objek: 0 }) },
    { hasil: line({ confidence: '0.2' }), ambang_confidence: '0.25' },
    { status_deteksi: 'sehat' },
    { tanggal_deteksi: '2026-09-29' },
    { model_versi: ' ' },
    { id_pemindahan: 1 },
    { tak_dikenal: 1 },
  ]) check(await post(body(bad)), 400);
});

test('only an image identity on Cloudinary over HTTPS is accepted', async (t) => {
  const { post, body } = await setup(t);
  for (const gambar of [
    { public_id: 'a', url: 'file:///storage/emulated/0/a.jpg' },
    { public_id: 'a', url: 'http://res.cloudinary.com/demo/image/upload/a.jpg' },
    { public_id: 'a', url: 'https://evil.example/res.cloudinary.com/a.jpg' },
    { public_id: 'a', url: 'https://res.cloudinary.com.evil.example/a.jpg' },
    { public_id: 'a', url: 'https://user:pw@res.cloudinary.com/demo/a.jpg' },
    { public_id: 'lain', url: 'https://res.cloudinary.com/demo/image/upload/a.jpg' },
    { public_id: '../a', url: 'https://res.cloudinary.com/demo/image/upload/../a.jpg' },
    { public_id: 'a', url: `https://res.cloudinary.com/demo/${'a'.repeat(500)}.jpg` },
    { url: 'https://res.cloudinary.com/demo/image/upload/a.jpg' },
  ]) check(await post(body({ gambar })), 400);
  check(await post(body({ gambar: null })), 201);
});

test('the batch and date must make sense', async (t) => {
  const { post, body, db } = await setup(t);
  check(await post(body({ id_pemindahan: '999' })), 422, 'TRANSFER_NOT_FOUND');
  // 2026-09-15 23:00 WIB is before the transfer on 2026-09-16.
  check(await post(body({ tanggal_deteksi: '2026-09-15T16:00:00Z' })), 400, 'INVALID_DETECTION_DATE');
  check(await post(body({ tanggal_deteksi: '2026-09-15T17:00:00Z' })), 201);
  // The fixture clock is 2026-09-30T00:00Z: small device clock drift passes, a later date does not.
  check(await post(body({ tanggal_deteksi: '2026-09-30T00:05:00Z' })), 201);
  check(await post(body({ tanggal_deteksi: '2026-09-30T00:05:01Z' })), 400, 'VALIDATION_ERROR');
  const stored = (await db.execute('SELECT COUNT(*) AS n FROM deteksi')).rows[0].n;
  assert.equal(Number(stored), 2);
});

test('a retry after a lost response does not store a second detection', async (t) => {
  const { db, post, body } = await setup(t);
  const key = { 'idempotency-key': randomUUID(), 'x-client-id': randomUUID() };
  const first = await post(body(), key);
  check(first, 201);
  const retry = await post(body(), key);
  check(retry, 200);
  assert.equal(retry.json().replayed, true);
  assert.equal(retry.json().data.id_deteksi, first.json().data.id_deteksi);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS n FROM deteksi')).rows[0].n), 1);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS n FROM hasil_deteksi')).rows[0].n), 1);
  check(await post(body({ model_versi: 'lain' }), key), 409, 'OPERATION_CONFLICT');
  check(await post(body(), {}, { omitIdempotencyKey: true }), 400);
});

test('a failure while storing results leaves nothing behind', async (t) => {
  const { db, post, body } = await setup(t);
  await db.execute("CREATE TRIGGER gagal_hasil BEFORE INSERT ON hasil_deteksi BEGIN SELECT RAISE(ABORT,'injected'); END");
  check(await post(body()), 500, 'INTERNAL_ERROR');
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS n FROM deteksi')).rows[0].n), 0);
  assert.equal(Number((await db.execute("SELECT COUNT(*) AS n FROM sync_resource_links WHERE resource_type='deteksi'")).rows[0].n), 0);
});

test('the image can be attached later, once, and results stay immutable', async (t) => {
  const { post, send, body } = await setup(t);
  check(await post(body()), 201);
  check(await send('PATCH', '/1', { hasil: [] }), 400);
  check(await send('PATCH', '/1', { status_deteksi: 'gagal' }), 400);
  check(await send('PATCH', '/1', { expected_version: '1' }), 400);
  check(await send('PATCH', '/1', { gambar: image, expected_version: '9' }), 409, 'VERSION_CONFLICT');
  const attached = await send('PATCH', '/1', { gambar: image, expected_version: '1' });
  check(attached, 200);
  assert.deepEqual(attached.json().data.gambar, image);
  assert.equal(attached.json().data.version, '2');
  check(await send('PATCH', '/1', { gambar: image }), 200);
  const other = { public_id: 'lain', url: 'https://res.cloudinary.com/demo/image/upload/lain.jpg' };
  check(await send('PATCH', '/1', { gambar: other }), 409, 'DETECTION_IMAGE_LOCKED');
  check(await send('PATCH', '/1', { gambar: null }), 400);
  check(await send('PATCH', '/999', { keterangan: 'x' }), 404, 'DETECTION_NOT_FOUND');
  check(await send('PATCH', '/1', { keterangan: 'x' }, { 'x-client-id': randomUUID() }), 400);
});

test('lists filter by batch and status, in stable order, with a constant query count', async (t) => {
  const { db, post, send, body } = await setup(t);
  for (let i = 0; i < 20; i += 1) check(await post(body({ id_pemindahan: i % 2 ? '2' : '1', tanggal_deteksi: `2026-09-${String(20 + (i % 5)).padStart(2, '0')}T00:00:00Z` })), 201);
  check(await post(body({ status_deteksi: 'tanpa_deteksi', hasil: [] })), 201);
  let queries = 0;
  const transaction = db.transaction.bind(db);
  db.transaction = async (mode) => {
    const tx = await transaction(mode);
    const execute = tx.execute.bind(tx);
    tx.execute = (...args) => { queries += 1; return execute(...args); };
    return tx;
  };
  const all = await send('GET', '?limit=100');
  db.transaction = transaction;
  check(all, 200);
  assert.ok(queries <= 3, `expected at most 3 queries, ran ${queries}`);
  assert.equal(all.json().meta.total, 21);
  const rows = all.json().data;
  assert.deepEqual(rows[20], (await send('GET', `/${rows[20].id_deteksi}`)).json().data);
  const dates = rows.map((row) => row.tanggal_deteksi);
  assert.deepEqual(dates, [...dates].sort().reverse());
  const batch = await send('GET', '?id_pemindahan=2');
  assert.equal(batch.json().meta.total, 10);
  assert.ok(batch.json().data.every((row) => row.id_pemindahan === '2'));
  assert.equal((await send('GET', '?status_deteksi=tanpa_deteksi')).json().meta.total, 1);
  check(await send('GET', '?status_deteksi=sehat'), 400);
  check(await send('GET', '/999'), 404, 'DETECTION_NOT_FOUND');
  assert.deepEqual((await send('GET', '?page=50')).json().data, []);
});

test('every door: anonymous, expired and pegawai cannot reach detections', async (t) => {
  const { app, pegawai, post, body, advance } = await setup(t);
  check(await post(body()), 201);
  const request = (headers, method = 'GET', url = '/api/v1/deteksi', payload) => app.inject({ method, url, headers, payload });
  check(await request({}), 401);
  check(await request({ authorization: `Bearer ${'a'.repeat(43)}` }), 401);
  check(await request(pegawai), 403, 'FORBIDDEN');
  check(await request(pegawai, 'GET', '/api/v1/deteksi/1'), 403);
  check(await request({ ...pegawai, 'idempotency-key': randomUUID() }, 'POST', '/api/v1/deteksi', body()), 403);
  check(await request({ ...pegawai, 'idempotency-key': randomUUID() }, 'PATCH', '/api/v1/deteksi/1', { keterangan: 'x' }), 403);
  advance(16 * 60 * 1000);
  check(await post(body()), 401);
});

test('migration keeps old detections and recommendations, and rolls back', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const all = await loadMigrations();
  const index = all.findIndex((migration) => migration.id.endsWith('_detections'));
  assert.ok(index > 0);
  await migrate(db, all.slice(0, index));
  await db.executeMultiple(`
    INSERT INTO roles(nama_role) VALUES('petani');
    INSERT INTO users(id_role,nama,username,password) VALUES(1,'P','p','h');
    INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih) VALUES(1,'2026-09-01',10);
    INSERT INTO meja_tanam(kode_meja,jumlah_lubang) VALUES('M1',10);
    INSERT INTO pemindahan(id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES(1,1,'2026-09-16',5);
    INSERT INTO obat(nama_obat) VALUES('O');
    INSERT INTO hasil_deteksi(id_hasil_deteksi,id_pemindahan,gambar,nama_hama,confidence,tanggal_deteksi) VALUES(7,1,'https://contoh/a.jpg','thrips',0.875,'2026-09-20 01:02:03');
    INSERT INTO rekomendasi_perawatan(id_hasil_deteksi,id_obat) VALUES(7,1);
  `);
  await migrate(db, all.slice(0, index + 1));
  const up = (await db.execute(`SELECT h.id_hasil_deteksi,h.nama_hama,h.confidence_minor,d.id_pemindahan,d.id_user,d.gambar_url,d.status_deteksi,d.tanggal_deteksi
    FROM hasil_deteksi h JOIN deteksi d ON d.id_deteksi=h.id_deteksi`)).rows[0];
  assert.deepEqual([up.id_hasil_deteksi, up.nama_hama, up.confidence_minor, up.id_pemindahan, up.id_user, up.gambar_url, up.status_deteksi, up.tanggal_deteksi],
    [7, 'thrips', 8750, 1, null, 'https://contoh/a.jpg', 'terdeteksi', '2026-09-20 01:02:03']);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS n FROM rekomendasi_perawatan WHERE id_hasil_deteksi=7')).rows[0].n), 1);
  assert.equal((await db.execute('PRAGMA foreign_key_check')).rows.length, 0);
  await assert.rejects(db.execute("INSERT INTO rekomendasi_perawatan(id_hasil_deteksi,id_obat) VALUES(99,1)"), /FOREIGN KEY/);

  await migrate(db, all.slice(0, index + 1), { direction: 'down', allowDataLoss: true });
  const down = (await db.execute('SELECT id_hasil_deteksi,id_pemindahan,gambar,nama_hama,confidence,tanggal_deteksi FROM hasil_deteksi')).rows[0];
  assert.deepEqual([down.id_hasil_deteksi, down.id_pemindahan, down.gambar, down.nama_hama, down.confidence, down.tanggal_deteksi],
    [7, 1, 'https://contoh/a.jpg', 'thrips', 0.875, '2026-09-20 01:02:03']);
  assert.equal(Number((await db.execute("SELECT COUNT(*) AS n FROM sqlite_master WHERE name='deteksi'")).rows[0].n), 0);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS n FROM rekomendasi_perawatan')).rows[0].n), 1);
  await migrate(db, all.slice(0, index + 1));
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS n FROM hasil_deteksi')).rows[0].n), 1);
});
