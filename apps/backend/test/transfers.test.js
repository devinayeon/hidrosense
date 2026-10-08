import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { fixture, bearer } from '../test-support/fixture.js';

async function setup(t) {
  const f = await fixture(t);
  const token = (await f.login('pegawai')).json().data.access_token;
  const headers = bearer(token);

  // Setup initial sowing and growing table
  await f.db.executeMultiple(`
    INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian, keterangan)
    VALUES (2, '2026-09-01', 500, 'aktif', 'Semai Batch 1');
    INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja, keterangan)
    VALUES ('M-01', 250, 'tersedia', 'Meja NFT 1'),
           ('M-02', 200, 'perbaikan', 'Meja Rusak');
  `);

  const send = (method, path = '', payload, extra = {}) =>
    f.app.inject({
      method,
      url: `/api/v1/pemindahan${path}`,
      payload,
      headers: { ...headers, ...extra },
    });

  const create = (body = {}, extra = {}) =>
    send(
      'POST',
      '',
      {
        id_penyemaian: '1',
        id_meja: '1',
        tanggal_pemindahan: '2026-09-16',
        jumlah_tanaman: 150,
        keterangan: 'Pindah ke M-01',
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

test('transfer updates remaining seedlings and table holes on list and detail without double-counting replay', async (t) => {
  const f = await setup(t);
  const get = async (path) => {
    const response = await f.app.inject({ method: 'GET', url: `/api/v1/${path}`, headers: f.headers });
    check(response, 200);
    return response.json().data;
  };
  assert.equal((await get('penyemaian/1')).sisa_benih, 500);
  const key = randomUUID();
  check(await f.create({}, { 'idempotency-key': key }), 201);
  check(await f.create({}, { 'idempotency-key': key }), 200);
  for (const sowing of [(await get('penyemaian'))[0], await get('penyemaian/1')]) {
    assert.equal(sowing.jumlah_benih, 500);
    assert.equal(sowing.sisa_benih, 350);
  }
  for (const table of [(await get('meja-tanam'))[0], await get('meja-tanam/1')]) {
    assert.equal(table.tanaman_aktif, 150);
    assert.equal(table.kapasitas_tersedia, 100);
  }
  check(await f.create({ jumlah_tanaman: 101 }), 409, 'TABLE_CAPACITY_EXCEEDED');
  assert.equal((await get('penyemaian/1')).sisa_benih, 350);
  await f.db.execute("INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja) VALUES ('M-03', 350, 'tersedia')");
  check(await f.create({ id_meja: '3', jumlah_tanaman: 350 }), 201);
  const completed = await get('penyemaian/1');
  assert.equal(completed.sisa_benih, 0);
  assert.equal(completed.status_penyemaian, 'selesai');
});

test('transfers create calculates harvest date based on 45-day baseline, umur_semai, and active plants', async (t) => {
  const f = await setup(t);
  const res = await f.create();
  check(res, 201);
  const d = res.json().data;

  assert.equal(d.id_pemindahan, '1');
  assert.equal(d.id_penyemaian, '1');
  assert.equal(d.id_meja, '1');
  assert.equal(d.kode_meja, 'M-01');
  assert.equal(d.tanggal_semai, '2026-09-01');
  assert.equal(d.tanggal_pemindahan, '2026-09-16');
  assert.equal(d.jumlah_tanaman, 150);
  assert.equal(d.tanaman_aktif, 150);

  // 15 days seedling duration: 2026-09-16 - 2026-09-01 = 15
  assert.equal(d.umur_semai_hari, 15);
  // Harvest calculation: 2026-09-01 + 45 days = 2026-10-16
  assert.equal(d.estimasi_panen, '2026-10-16');
  assert.equal(d.version, '1');
  assert.ok(d.public_id);
});

test('transfers reject seedling younger than 15 days or invalid dates', async (t) => {
  const f = await setup(t);

  // 14 days old (not ready)
  const tooEarly = await f.create({ tanggal_pemindahan: '2026-09-15' });
  check(tooEarly, 400, 'SEEDLING_NOT_READY');

  // Date before sowing
  const beforeSowing = await f.create({ tanggal_pemindahan: '2026-08-30' });
  check(beforeSowing, 400, 'INVALID_TRANSFER_DATE');

  // Invalid calendar format / non-existent date
  const invalidDate = await f.create({ tanggal_pemindahan: '2026-02-30' });
  check(invalidDate, 400, 'VALIDATION_ERROR');
});

test('transfers enforce seedling availability limit and auto-complete sowing when exhausted', async (t) => {
  const f = await setup(t);

  // Transfer 200 out of 500 (sisa: 300, table M-01 has 250 holes so 200 fits)
  const first = await f.create({ jumlah_tanaman: 200 });
  check(first, 201);

  // Create another table M-03 with 400 holes
  await f.db.execute("INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja) VALUES ('M-03', 400, 'tersedia')");

  // Attempt to transfer 301 (exceeds available 300)
  const exceed = await f.create({ id_meja: '3', jumlah_tanaman: 301 });
  check(exceed, 409, 'SEEDLING_INSUFFICIENT');

  // Transfer remaining 300 to M-03
  const second = await f.create({ id_meja: '3', jumlah_tanaman: 300 });
  check(second, 201);

  // Check sowing status is now 'selesai'
  const sowingStatus = (await f.db.execute('SELECT status_penyemaian FROM penyemaian WHERE id_penyemaian = 1')).rows[0].status_penyemaian;
  assert.equal(sowingStatus, 'selesai');

  // Any subsequent transfer attempt on completed sowing should fail
  const onDone = await f.create({ id_meja: '3', jumlah_tanaman: 10 });
  check(onDone, 409, 'SOWING_INACTIVE');
});

test('transfers enforce table hole capacity limits and unavailable table status', async (t) => {
  const f = await setup(t);

  // Table M-01 has 250 holes. Transfer 200 holes first.
  const first = await f.create({ jumlah_tanaman: 200 });
  check(first, 201);

  // Transfer 51 holes (200 + 51 = 251 > 250)
  const exceed = await f.create({ jumlah_tanaman: 51 });
  check(exceed, 409, 'TABLE_CAPACITY_EXCEEDED');

  // Attempt transfer to table M-02 (status 'perbaikan')
  const toBroken = await f.create({ id_meja: '2', jumlah_tanaman: 50 });
  check(toBroken, 409, 'TABLE_NOT_AVAILABLE');
});

test('transfers list, detail, pagination, and filter', async (t) => {
  const f = await setup(t);
  await f.create({ jumlah_tanaman: 100 });
  await f.db.execute("INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja) VALUES ('M-03', 300, 'tersedia')");
  await f.create({ id_meja: '3', jumlah_tanaman: 50 });

  // List all
  const list = (await f.send('GET', '?limit=10&page=1')).json();
  assert.equal(list.meta.total, 2);
  assert.equal(list.data.length, 2);

  // Filter by id_meja
  const filteredMeja = (await f.send('GET', '?id_meja=3')).json();
  assert.equal(filteredMeja.meta.total, 1);
  assert.equal(filteredMeja.data[0].id_meja, '3');

  // Detail GET
  const detail = (await f.send('GET', '/1')).json().data;
  assert.equal(detail.id_pemindahan, '1');
  assert.equal(detail.jumlah_tanaman, 100);
});

test('transfers patch keterangan and idempotency replay', async (t) => {
  const f = await setup(t);
  const key = randomUUID();
  const clientId = randomUUID();

  const headers = { 'idempotency-key': key, 'x-client-id': clientId };

  // Create with idempotency key
  const first = await f.create({}, headers);
  check(first, 201);

  // Replay exact same request
  const replay = await f.create({}, headers);
  check(replay, 200);
  assert.equal(replay.json().replayed, true);
  assert.deepEqual(replay.json().data, first.json().data);

  // Idempotency conflict with different payload
  const conflict = await f.create({ jumlah_tanaman: 200 }, headers);
  check(conflict, 409, 'OPERATION_CONFLICT');

  // Patch keterangan
  const patched = await f.send('PATCH', '/1', { keterangan: 'Keterangan baru diupdate' });
  check(patched, 200);
  assert.equal(patched.json().data.keterangan, 'Keterangan baru diupdate');
  assert.equal(patched.json().data.version, '2');
});

test('transfers permissions: petani can read but cannot create or patch', async (t) => {
  const f = await setup(t);
  await f.create();

  // Login as petani
  const petaniToken = (await f.login('petani')).json().data.access_token;
  const petaniHeaders = bearer(petaniToken);

  // Petani can read list & detail
  const readList = await f.app.inject({ method: 'GET', url: '/api/v1/pemindahan', headers: petaniHeaders });
  check(readList, 200);

  const readDetail = await f.app.inject({ method: 'GET', url: '/api/v1/pemindahan/1', headers: petaniHeaders });
  check(readDetail, 200);

  // Petani forbidden from creating or updating
  const createForbidden = await f.app.inject({
    method: 'POST',
    url: '/api/v1/pemindahan',
    headers: petaniHeaders,
    payload: { id_penyemaian: '1', id_meja: '1', tanggal_pemindahan: '2026-09-16', jumlah_tanaman: 50 },
  });
  check(createForbidden, 403);

  const patchForbidden = await f.app.inject({
    method: 'PATCH',
    url: '/api/v1/pemindahan/1',
    headers: petaniHeaders,
    payload: { keterangan: 'Hack' },
  });
  check(patchForbidden, 403);
});
