import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { fixture, bearer } from '../test-support/fixture.js';

async function setup(t) {
  const f = await fixture(t);
  const token = (await f.login('pegawai')).json().data.access_token;
  const headers = bearer(token);

  // Sowing: 500 benih, transfer 200 to table M-01
  await f.db.executeMultiple(`
    INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian)
    VALUES (2, '2026-09-01', 500, 'aktif');
    INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja)
    VALUES ('M-01', 250, 'tersedia');
    INSERT INTO pemindahan (id_penyemaian, id_meja, tanggal_pemindahan, jumlah_tanaman)
    VALUES (1, 1, '2026-09-16', 200);
  `);

  const send = (method, path = '', payload, extra = {}) =>
    f.app.inject({
      method,
      url: `/api/v1/kerusakan${path}`,
      payload,
      headers: { ...headers, ...extra },
    });

  const create = (body = {}, extra = {}) =>
    send(
      'POST',
      '',
      {
        id_pemindahan: '1',
        tanggal_kejadian: '2026-09-20',
        jumlah_tanaman: 10,
        jenis_kerusakan: 'Busuk akar',
        keterangan: null,
        ...body,
      },
      extra,
    );

  return { ...f, headers, send, create };
}

function check(response, status, code) {
  assert.equal(response.statusCode, status, response.body);
  if (code) assert.equal(response.json().error.code, code);
}

test('damage create records kerusakan and returns correct shape', async (t) => {
  const f = await setup(t);
  const res = await f.create();
  check(res, 201);
  const d = res.json().data;

  assert.equal(d.id_kerusakan, '1');
  assert.equal(d.id_pemindahan, '1');
  assert.equal(d.tanggal_kejadian, '2026-09-20');
  assert.equal(d.jumlah_tanaman, 10);
  assert.equal(d.jenis_kerusakan, 'Busuk akar');
  assert.equal(d.keterangan, null);
  assert.equal(d.version, '1');
  assert.ok(d.public_id);
});

test('damage rejects invalid date and missing required fields', async (t) => {
  const f = await setup(t);

  // Invalid calendar date
  const badDate = await f.create({ tanggal_kejadian: '2026-02-30' });
  check(badDate, 400, 'VALIDATION_ERROR');

  // Missing jenis_kerusakan
  const noType = await f.app.inject({
    method: 'POST',
    url: '/api/v1/kerusakan',
    headers: bearer((await f.login('pegawai')).json().data.access_token),
    payload: { id_pemindahan: '1', tanggal_kejadian: '2026-09-20', jumlah_tanaman: 5 },
  });
  check(noType, 400, 'VALIDATION_ERROR');

  // Transfer not found
  const notFound = await f.create({ id_pemindahan: '999' });
  check(notFound, 404, 'TRANSFER_NOT_FOUND');
});

test('damage enforces active plant limit: cannot exceed jumlah_tanaman on transfer', async (t) => {
  const f = await setup(t);

  // Transfer has 200 plants. Record 195 damage first.
  await f.create({ jumlah_tanaman: 195 });

  // 195 + 10 = 205 > 200 — should fail
  const exceed = await f.create({ jumlah_tanaman: 10 });
  check(exceed, 409, 'DAMAGE_EXCEEDS_ACTIVE');

  // Exact remaining (5) should succeed
  const exact = await f.create({ jumlah_tanaman: 5 });
  check(exact, 201);
});

test('damage list, detail, pagination, and filter by id_pemindahan', async (t) => {
  const f = await setup(t);

  // Insert a second transfer on another table
  await f.db.execute("INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja) VALUES ('M-02', 250, 'tersedia')");
  await f.db.execute('INSERT INTO pemindahan (id_penyemaian, id_meja, tanggal_pemindahan, jumlah_tanaman) VALUES (1, 2, \'2026-09-16\', 100)');

  await f.create({ id_pemindahan: '1', jumlah_tanaman: 20 });
  await f.create({ id_pemindahan: '2', jumlah_tanaman: 15 });

  // List all
  const list = (await f.send('GET', '?limit=10&page=1')).json();
  assert.equal(list.meta.total, 2);
  assert.equal(list.data.length, 2);

  // Filter by id_pemindahan
  const filtered = (await f.send('GET', '?id_pemindahan=1')).json();
  assert.equal(filtered.meta.total, 1);
  assert.equal(filtered.data[0].id_pemindahan, '1');

  // Detail GET
  const detail = (await f.send('GET', '/1')).json().data;
  assert.equal(detail.id_kerusakan, '1');
  assert.equal(detail.jumlah_tanaman, 20);
});

test('damage patch updates fields and increments version', async (t) => {
  const f = await setup(t);
  await f.create({ jumlah_tanaman: 10 });

  const patched = await f.send('PATCH', '/1', {
    jenis_kerusakan: 'Kutu daun',
    jumlah_tanaman: 15,
  });
  check(patched, 200);
  const d = patched.json().data;
  assert.equal(d.jenis_kerusakan, 'Kutu daun');
  assert.equal(d.jumlah_tanaman, 15);
  assert.equal(d.version, '2');
});

test('damage patch rejects jumlah exceeding active plants', async (t) => {
  const f = await setup(t);
  // Record 190 damage
  await f.create({ jumlah_tanaman: 190 });

  // Try to update to 201 (exceeds 200 total on transfer)
  const exceed = await f.send('PATCH', '/1', { jumlah_tanaman: 201 });
  check(exceed, 409, 'DAMAGE_EXCEEDS_ACTIVE');
});

test('damage idempotency replay returns same result', async (t) => {
  const f = await setup(t);
  const key = randomUUID();
  const clientId = randomUUID();
  const extra = { 'idempotency-key': key, 'x-client-id': clientId };

  const first = await f.create({}, extra);
  check(first, 201);

  // Replay same request
  const replay = await f.create({}, extra);
  check(replay, 200);
  assert.equal(replay.json().replayed, true);
  assert.deepEqual(replay.json().data, first.json().data);

  // Conflict: same key, different payload
  const conflict = await f.create({ jumlah_tanaman: 50 }, extra);
  check(conflict, 409, 'OPERATION_CONFLICT');
});

test('damage permissions: petani can read but cannot create or patch', async (t) => {
  const f = await setup(t);
  await f.create();

  const petaniToken = (await f.login('petani')).json().data.access_token;
  const petaniHeaders = bearer(petaniToken);

  // Petani can read list & detail
  const readList = await f.app.inject({ method: 'GET', url: '/api/v1/kerusakan', headers: petaniHeaders });
  check(readList, 200);

  const readDetail = await f.app.inject({ method: 'GET', url: '/api/v1/kerusakan/1', headers: petaniHeaders });
  check(readDetail, 200);

  // Petani forbidden from write
  const createForbidden = await f.app.inject({
    method: 'POST',
    url: '/api/v1/kerusakan',
    headers: petaniHeaders,
    payload: { id_pemindahan: '1', tanggal_kejadian: '2026-09-20', jumlah_tanaman: 5, jenis_kerusakan: 'Test' },
  });
  check(createForbidden, 403);

  const patchForbidden = await f.app.inject({
    method: 'PATCH',
    url: '/api/v1/kerusakan/1',
    headers: petaniHeaders,
    payload: { keterangan: 'Hack' },
  });
  check(patchForbidden, 403);
});

test('damage tanaman_aktif reflected in transfer response after recording damage', async (t) => {
  const f = await setup(t);
  await f.create({ jumlah_tanaman: 30 });

  // Check transfer detail — tanaman_aktif should be 200 - 30 = 170
  const transferDetail = await f.app.inject({
    method: 'GET',
    url: '/api/v1/pemindahan/1',
    headers: bearer((await f.login('pegawai')).json().data.access_token),
  });
  assert.equal(transferDetail.statusCode, 200);
  assert.equal(transferDetail.json().data.tanaman_aktif, 170);
});
