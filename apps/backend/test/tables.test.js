import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { fixture, bearer } from '../test-support/fixture.js';
async function setup(t) {
  const f = await fixture(t);
  const headers = bearer((await f.login('pegawai')).json().data.access_token);
  const send = (method, path = '', payload, extra = {}) => f.app.inject({ method, url: `/api/v1/meja-tanam${path}`, payload, headers: { ...headers, ...extra } });
  return { ...f, headers, send, create: (body = {}, extra) => send('POST', '', { kode_meja: 'M-01', jumlah_lubang: 250, keterangan: 'Tetap', ...body }, extra) };
}
function check(response, status, code) {
  assert.equal(response.statusCode, status, response.body);
  if (code) assert.equal(response.json().error.code, code);
}
test('tables create, partial updates, status manual, stable identity and detail', async (t) => {
  const f = await setup(t);
  const first = await f.create({ kode_meja: ' M-01 ' }); check(first, 201);
  const d = first.json().data;
  assert.equal(d.kode_meja, 'M-01'); assert.equal(d.version, '1');
  assert.equal(d.tanaman_aktif, 0); assert.equal(d.kapasitas_tersedia, 250);
  const changed = await f.send('PATCH', `/${d.id_meja}`, { status_meja: 'perbaikan' }); check(changed, 200);
  assert.equal(changed.json().data.keterangan, 'Tetap');
  assert.equal(changed.json().data.public_id, d.public_id); assert.equal(changed.json().data.version, '2');
  const cleared = await f.send('PATCH', `/${d.id_meja}`, { keterangan: null });
  assert.equal(cleared.json().data.keterangan, null);
  assert.deepEqual((await f.send('GET', `/${d.id_meja}`)).json().data, cleared.json().data);
});
test('tables replay, conflicting keys, reserved identity and patch replay', async (t) => {
  const f = await setup(t);
  const headers = { 'idempotency-key': randomUUID(), 'x-client-id': randomUUID() };
  const first = await f.create({}, headers); check(first, 201);
  const again = await f.create({}, headers); check(again, 200);
  assert.equal(again.json().replayed, true); assert.deepEqual(again.json().data, first.json().data);
  check(await f.create({ jumlah_lubang: 300 }, headers), 409, 'OPERATION_CONFLICT');
  check(await f.create({}, { 'x-client-id': headers['x-client-id'] }), 409, 'RESOURCE_ALREADY_EXISTS');
  const key = { 'idempotency-key': randomUUID() }, path = `/${first.json().data.id_meja}`;
  const changed = await f.send('PATCH', path, { jumlah_lubang: 300 }, key);
  const replay = await f.send('PATCH', path, { jumlah_lubang: 300 }, key);
  assert.deepEqual(replay.json().data, changed.json().data); assert.equal(replay.json().data.version, '2');
  check(await f.send('PATCH', path, { jumlah_lubang: 301 }, key), 409);
  assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM meja_tanam')).rows[0].n, 1);
  assert.equal((await f.db.execute("SELECT COUNT(*) AS n FROM sync_operations WHERE operation_type LIKE 'meja-tanam.%'")).rows[0].n, 2);
});
test('tables unique code, pagination and status filter', async (t) => {
  const f = await setup(t); const a = (await f.create()).json().data;
  const b = (await f.create({ kode_meja: 'M-02', status_meja: 'perbaikan' })).json().data;
  check(await f.create(), 409, 'TABLE_CODE_CONFLICT');
  check(await f.send('PATCH', `/${b.id_meja}`, { kode_meja: a.kode_meja }), 409, 'TABLE_CODE_CONFLICT');
  const listed = (await f.send('GET', '?limit=1&page=2')).json();
  assert.equal(listed.meta.total, 2); assert.equal(listed.data[0].id_meja, b.id_meja);
  const filtered = (await f.send('GET', '?status_meja=perbaikan')).json();
  assert.equal(filtered.meta.total, 1); assert.equal(filtered.data[0].id_meja, b.id_meja);
});
test('tables reject invalid bodies, parameters and headers', async (t) => {
  const f = await setup(t);
  for (const body of [{ jumlah_lubang: 0 }, { jumlah_lubang: -1 }, { jumlah_lubang: 1.5 }, { jumlah_lubang: '250' },
    { jumlah_lubang: 9007199254740992 }, { kode_meja: ' ' }, { status_meja: '' }, { kode_meja: 'a'.repeat(31) }, { unknown: 1 }]) check(await f.create(body), 400);
  const d = (await f.create()).json().data;
  check(await f.send('PATCH', `/${d.id_meja}`, {}), 400);
  check(await f.send('PATCH', `/${d.id_meja}`, { status_meja: 'rusak' }, { 'x-client-id': randomUUID() }), 400);
  check(await f.create({}, { 'idempotency-key': 'bad' }), 400);
  for (const path of ['?limit=101', '?foo=1', '/0', '/9223372036854775808', '/1?foo=1']) check(await f.send('GET', path), 400);
  check(await f.send('GET', '/999'), 404, 'TABLE_NOT_FOUND');
  check(await f.send('PATCH', '/999', { jumlah_lubang: 1 }), 404);
});
test('tables permissions, anonymous and inactive users', async (t) => {
  const f = await setup(t); const d = (await f.create()).json().data;
  const headers = bearer((await f.login()).json().data.access_token);
  check(await f.app.inject({ url: '/api/v1/meja-tanam', headers }), 200);
  for (const method of ['POST', 'PATCH']) check(await f.app.inject({ method,
    url: `/api/v1/meja-tanam${method === 'PATCH' ? `/${d.id_meja}` : ''}`, headers, payload: { kode_meja: 'X', jumlah_lubang: 10 } }), 403);
  check(await f.app.inject({ url: '/api/v1/meja-tanam' }), 401);
  await f.db.execute("UPDATE users SET status_aktif=0 WHERE username='pegawai'");
  check(await f.send('PATCH', `/${d.id_meja}`, { jumlah_lubang: 1 }), 401);
});
async function plants(db, id) {
  await db.executeMultiple("INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih,status_penyemaian) VALUES(2,'2026-09-01',500,'aktif'); INSERT INTO panen(id_user,tanggal_panen) VALUES(2,'2026-09-30');");
  for (const count of [100, 50]) await db.execute({ sql: "INSERT INTO pemindahan(id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES(1,?,'2026-09-16',?)", args: [id, count] });
  await db.executeMultiple(`INSERT INTO kerusakan_tanaman(id_pemindahan,tanggal_kejadian,jumlah_tanaman,jenis_kerusakan) VALUES(1,'2026-09-20',10,'rusak'),(1,'2026-09-21',5,'rusak');
    INSERT INTO detail_panen(id_panen,id_pemindahan,jumlah_tanaman,berat) VALUES(1,1,20,2),(1,1,10,1),(1,2,5,1);`);
}
test('tables active count avoids join multiplication; capacity failure rolls back receipt and fields', async (t) => {
  const f = await setup(t); const id = (await f.create()).json().data.id_meja; await plants(f.db, id);
  const d = (await f.send('GET', `/${id}`)).json().data;
  assert.equal(d.tanaman_aktif, 100); assert.equal(d.kapasitas_tersedia, 150);
  const headers = { 'idempotency-key': randomUUID() };
  check(await f.send('PATCH', `/${id}`, { jumlah_lubang: 99, status_meja: 'rusak' }, headers), 409, 'TABLE_UNDERCAPACITY');
  const after = (await f.send('GET', `/${id}`)).json().data;
  assert.equal(after.version, '1'); assert.equal(after.status_meja, 'tersedia');
  assert.equal((await f.db.execute({ sql: 'SELECT 1 FROM sync_operations WHERE operation_key=?', args: [headers['idempotency-key']] })).rows.length, 0);
  const exact = await f.send('PATCH', `/${id}`, { jumlah_lubang: 100 }, headers); check(exact, 200);
  assert.equal(exact.json().data.kapasitas_tersedia, 0);
});
test('tables reject negative per-batch balance hidden by another batch', async (t) => {
  const f = await setup(t); const id = (await f.create()).json().data.id_meja; await plants(f.db, id);
  await f.db.execute("INSERT INTO kerusakan_tanaman(id_pemindahan,tanggal_kejadian,jumlah_tanaman,jenis_kerusakan) VALUES(1,'2026-09-22',60,'rusak')");
  check(await f.send('GET', `/${id}`), 409, 'TABLE_BALANCE_INVALID');
});
test('tables preserve signed64 legacy IDs and initialize identity on edit', async (t) => {
  const f = await setup(t), id = '9007199254740993';
  await f.db.execute({ sql: "INSERT INTO meja_tanam(id_meja,kode_meja,jumlah_lubang) VALUES(?,'LEGACY',300)", args: [id] });
  const d = (await f.send('GET', `/${id}`)).json().data; assert.equal(d.id_meja, id); assert.equal(d.public_id, null);
  const changed = await f.send('PATCH', `/${id}`, { status_meja: 'perbaikan' }); check(changed, 200);
  assert.equal(changed.json().data.id_meja, id); assert.equal(changed.json().data.version, '1');
});

test('tables bind a B004 reserved UUID to the created table', async (t) => {
  const f = await setup(t), clientId = randomUUID();
  const reserved = await f.app.inject({ method: 'POST', url: '/api/v1/sync/operations', headers: f.headers,
    payload: { operation_key: randomUUID(), operation_type: 'sync.reserve-id', payload: {}, resource_type: 'meja-tanam', client_id: clientId } });
  check(reserved, 201);
  const created = await f.create({}, { 'x-client-id': clientId.toUpperCase() }); check(created, 201);
  assert.equal(created.json().data.public_id, reserved.json().data.public_id);
});
test('tables receipt failure rolls back row, mapping, resource identity and version', async (t) => {
  const f = await setup(t);
  await f.db.execute("CREATE TRIGGER fail_table_receipt BEFORE INSERT ON sync_operations BEGIN SELECT RAISE(ABORT,'failure'); END");
  check(await f.create({}, { 'idempotency-key': randomUUID(), 'x-client-id': randomUUID() }), 500);
  for (const table of ['meja_tanam', 'sync_id_maps', 'sync_resource_links', 'sync_resource_versions', 'sync_operations']) {
    assert.equal((await f.db.execute(`SELECT COUNT(*) AS n FROM ${table}`)).rows[0].n, 0);
  }
});
