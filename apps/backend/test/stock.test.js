import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { stockFixture, expectError, stockState } from '../test-support/stock-fixture.js';

test('stock balance reads do not create projection and enforce exact minimum thresholds', async (t) => {
  const f = await stockFixture(t);
  assert.deepEqual(await f.balance(), { id_inventaris: f.items[0].id_inventaris,
    satuan: 'kg', saldo: '0', stok_minimum: '0.1', di_bawah_minimum: true });
  assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM stok_saldo')).rows[0].n, 0);
  assert.equal((await f.balance(f.items[1])).di_bawah_minimum, false);
  const incoming = await f.post(f.movement('masuk', '0.10'));
  assert.equal(incoming.statusCode, 201, incoming.body);
  assert.equal((await f.balance()).di_bawah_minimum, false);
  const changed = await f.app.inject({ method: 'PATCH',
    url: `/api/v1/inventaris/${f.items[0].id_inventaris}`, headers: f.headers,
    payload: { stok_minimum: '00.11' } });
  assert.equal(changed.statusCode, 200, changed.body);
  assert.equal((await f.balance()).stok_minimum, '0.11');
  assert.equal((await f.balance()).di_bawah_minimum, true);
  assert.equal((await f.db.execute('SELECT stok_minimum_minor FROM inventaris ORDER BY id_inventaris')).rows[0].stok_minimum_minor, 11);
  await f.app.inject({ method: 'PATCH', url: `/api/v1/inventaris/${f.items[0].id_inventaris}`,
    headers: f.headers, payload: { stok_minimum: null } });
  assert.equal((await f.balance()).di_bawah_minimum, false);
});

test('stock history preserves actor, time, exact canonical quantities and complete filtered details', async (t) => {
  const f = await stockFixture(t);
  const payload = { jenis_stok: 'masuk', keterangan: '  Supplier  ', details: [
    { id_inventaris: f.items[1].id_inventaris, jumlah: '001.20', satuan: ' kg ' },
    { id_inventaris: f.items[0].id_inventaris, jumlah: '0.10', satuan: 'kg' },
  ] };
  const created = await f.post(payload);
  assert.equal(created.statusCode, 201, created.body);
  const data = created.json().data;
  assert.deepEqual(Object.keys(data).sort(), ['id_stok', 'public_id', 'version', 'id_user',
    'id_penyemaian', 'id_perawatan', 'tanggal_stok', 'jenis_stok', 'keterangan', 'reversal_of', 'details'].sort());
  assert.equal(data.id_user, '2');
  assert.equal(data.version, '1');
  assert.equal(data.keterangan, 'Supplier');
  assert.match(data.tanggal_stok, /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/);
  assert.deepEqual(data.details.map((line) => [line.id_inventaris, line.jumlah, line.satuan]),
    [[f.items[0].id_inventaris, '0.1', 'kg'], [f.items[1].id_inventaris, '1.2', 'kg']]);
  for (const line of data.details) assert.equal(typeof line.id_detail_stok, 'string');
  assert.equal(created.headers.location, `/api/v1/stok/${data.id_stok}`);
  assert.deepEqual((await f.app.inject({ url: created.headers.location, headers: f.reader })).json().data, data);
  assert.equal((await f.post(f.movement('keluar', '0.01'))).statusCode, 201);
  const filtered = await f.app.inject({ headers: f.reader,
    url: `/api/v1/stok?id_inventaris=${f.items[1].id_inventaris}&jenis_stok=masuk&limit=1` });
  assert.equal(filtered.statusCode, 200, filtered.body);
  assert.deepEqual(filtered.json(), { data: [data], meta: { page: 1, limit: 1, total: 1, total_pages: 1 } });
  const all = (await f.app.inject({ url: '/api/v1/stok?limit=1', headers: f.reader })).json();
  assert.deepEqual(all.meta, { page: 1, limit: 1, total: 2, total_pages: 2 });
  assert.equal(all.data[0].id_stok, data.id_stok);
  const outside = (await f.app.inject({ url: '/api/v1/stok?page=9&limit=1', headers: f.reader })).json();
  assert.deepEqual(outside.data, []);
  assert.equal(outside.meta.total, 2);
  const empty = (await f.app.inject({ url: '/api/v1/stok?id_inventaris=999', headers: f.reader })).json();
  assert.equal(empty.meta.total_pages, 0);
});

test('stock parser rejects malformed amounts, duplicate lines, forged fields and invalid query IDs', async (t) => {
  const f = await stockFixture(t);
  const before = await stockState(f.db);
  for (const amount of ['0', '-1', '+1', '1.000', '1e2', ' 1', '1 ', '1,2', '.1', '1.', '10000000000', 1]) {
    expectError(await f.post(f.movement('masuk', amount)), 400, 'VALIDATION_ERROR');
  }
  const base = f.movement();
  for (const payload of [
    { ...base, jenis_stok: 'adjustment' }, { ...base, details: [] },
    { ...base, details: [...base.details, ...base.details] },
    { ...base, details: Array(101).fill(base.details[0]) },
    { ...base, id_user: '1' }, { ...base, tanggal_stok: '2026-10-03' },
    { ...base, id_penyemaian: '1' }, { ...base, id_perawatan: '1' }, { ...base, saldo: '100' },
    { ...base, details: [{ ...base.details[0], extra: true }] },
    { ...base, keterangan: '' }, { ...base, keterangan: 'x'.repeat(1001) },
  ]) expectError(await f.post(payload), 400, 'VALIDATION_ERROR');
  for (const id of ['0', '01', '-1', 'abc', '9223372036854775808']) {
    expectError(await f.app.inject({ url: `/api/v1/stok/${id}`, headers: f.headers }), 400, 'VALIDATION_ERROR');
    expectError(await f.app.inject({ url: `/api/v1/inventaris/${id}/saldo`, headers: f.headers }), 400, 'VALIDATION_ERROR');
  }
  for (const query of ['page=0', 'limit=101', 'jenis_stok=other', 'id_inventaris=01', 'extra=1']) {
    expectError(await f.app.inject({ url: `/api/v1/stok?${query}`, headers: f.headers }), 400, 'VALIDATION_ERROR');
  }
  expectError(await f.app.inject({ url: '/api/v1/stok/999', headers: f.headers }), 404, 'STOK_NOT_FOUND');
  expectError(await f.app.inject({ url: '/api/v1/inventaris/999/saldo', headers: f.headers }), 404, 'INVENTARIS_NOT_FOUND');
  assert.deepEqual(await stockState(f.db), before);
});

test('stock authorization allows petani write and blocks anonymous and revoked replay', async (t) => {
  const f = await stockFixture(t);
  for (const url of ['/api/v1/stok', '/api/v1/stok/1', `/api/v1/inventaris/${f.items[0].id_inventaris}/saldo`]) {
    assert.equal((await f.app.inject({ url })).statusCode, 401);
  }
  const request = { method: 'POST', url: '/api/v1/stok',
    headers: { ...f.reader, 'idempotency-key': randomUUID() }, payload: f.movement() };
  const first = await f.app.inject(request);
  assert.equal(first.statusCode, 201, first.body);
  assert.equal((await f.app.inject({ url: first.headers.location, headers: f.reader })).statusCode, 200);
  const reverseRes = await f.app.inject({ method: 'POST', url: `${first.headers.location}/reverse`,
    headers: { ...f.reader, 'idempotency-key': randomUUID() }, payload: { keterangan: 'Correction' } });
  assert.equal(reverseRes.statusCode, 201, reverseRes.body);
  const logout = await f.app.inject({ method: 'POST', url: '/api/v1/auth/logout', headers: f.headers });
  assert.equal(logout.statusCode, 204, logout.body);
  const pegawaiReq = { method: 'POST', url: '/api/v1/stok',
    headers: { ...f.headers, 'idempotency-key': randomUUID() }, payload: f.movement() };
  assert.equal((await f.app.inject(pegawaiReq)).statusCode, 401);
  assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM stok')).rows[0].n, 2);
});

test('stock fractional arithmetic remains exact and balances cannot cross zero or maximum', async (t) => {
  const f = await stockFixture(t);
  assert.equal((await f.post(f.movement('masuk', '0.1'))).statusCode, 201);
  assert.equal((await f.post(f.movement('masuk', '0.2'))).statusCode, 201);
  assert.equal((await f.balance()).saldo, '0.3');
  for (let i = 0; i < 30; i += 1) assert.equal((await f.post(f.movement('keluar', '0.01'))).statusCode, 201);
  assert.equal((await f.balance()).saldo, '0');
  expectError(await f.post(f.movement('keluar', '0.01')), 409, 'INSUFFICIENT_STOCK');
  assert.equal((await f.post(f.movement('masuk', '9999999999.99'))).statusCode, 201);
  assert.equal((await f.balance()).saldo, '9999999999.99');
  const before = await stockState(f.db);
  expectError(await f.post(f.movement('masuk', '0.01')), 409, 'STOCK_LIMIT_EXCEEDED');
  assert.deepEqual(await stockState(f.db), before);
  const row = (await f.db.execute('SELECT typeof(saldo_minor) AS type,CAST(saldo_minor AS TEXT) AS n FROM stok_saldo')).rows[0];
  assert.deepEqual({ type: row.type, n: row.n }, { type: 'integer', n: '999999999999' });
});

test('stock rejects missing/inactive items and exact unit mismatch without partial effects', async (t) => {
  const f = await stockFixture(t);
  expectError(await f.post(f.movement('masuk', '1', { id_inventaris: '999', satuan: 'kg' })), 422, 'INVENTARIS_NOT_AVAILABLE');
  expectError(await f.post(f.movement('masuk', '1', { ...f.items[0], satuan: 'KG' })), 422, 'UNIT_MISMATCH');
  await f.app.inject({ method: 'POST', url: `/api/v1/inventaris/${f.items[1].id_inventaris}/deactivate`, headers: f.headers });
  const before = await stockState(f.db);
  expectError(await f.post({ jenis_stok: 'masuk', details: [
    ...f.movement('masuk', '1').details, ...f.movement('masuk', '1', f.items[1]).details,
  ] }), 422, 'INVENTARIS_NOT_AVAILABLE');
  assert.deepEqual(await stockState(f.db), before);
  assert.equal((await f.balance(f.items[1])).saldo, '0');
});

test('whole reversal appends opposite lines once, preserves original and locks unit at zero', async (t) => {
  const f = await stockFixture(t);
  const first = await f.post(f.movement('masuk', '1.20'));
  assert.equal(first.statusCode, 201, first.body);
  const original = first.json().data;
  for (const payload of [{}, { keterangan: null }, { keterangan: ' ' }, { keterangan: 'Correction', extra: 1 }]) {
    expectError(await f.post(payload, {}, `${first.headers.location}/reverse`), 400, 'VALIDATION_ERROR');
  }
  await f.app.inject({ method: 'POST', url: `/api/v1/inventaris/${f.items[0].id_inventaris}/deactivate`, headers: f.headers });
  const reverse = await f.post({ keterangan: '  Wrong receipt  ' }, {}, `${first.headers.location}/reverse`);
  assert.equal(reverse.statusCode, 201, reverse.body);
  const reversed = reverse.json().data;
  assert.equal(reversed.jenis_stok, 'keluar');
  assert.equal(reversed.reversal_of, original.id_stok);
  assert.notEqual(reversed.id_stok, original.id_stok);
  assert.notEqual(reversed.public_id, original.public_id);
  assert.equal(reversed.version, '1');
  assert.equal(reversed.keterangan, 'Wrong receipt');
  assert.equal(reversed.details[0].jumlah, '1.2');
  assert.equal((await f.balance()).saldo, '0');
  assert.deepEqual((await f.app.inject({ url: first.headers.location, headers: f.headers })).json().data, original);
  expectError(await f.post({ keterangan: 'Again' }, {}, `${first.headers.location}/reverse`), 409, 'STOK_ALREADY_REVERSED');
  expectError(await f.post({ keterangan: 'Reverse reversal' }, {}, `${reverse.headers.location}/reverse`), 409, 'REVERSAL_NOT_ALLOWED');
  const patch = await f.app.inject({ method: 'PATCH', url: `/api/v1/inventaris/${f.items[0].id_inventaris}`,
    headers: f.headers, payload: { satuan: 'ml' } });
  expectError(patch, 409, 'UNIT_LOCKED');
});

test('reversing incoming stock requires full current balance and multiitem deduction is atomic', async (t) => {
  const f = await stockFixture(t);
  const receipt = await f.post(f.movement('masuk', '2'));
  assert.equal((await f.post(f.movement('keluar', '1'))).statusCode, 201);
  const before = await stockState(f.db);
  expectError(await f.post({ keterangan: 'Reverse receipt' }, {}, `${receipt.headers.location}/reverse`), 409, 'INSUFFICIENT_STOCK');
  expectError(await f.post({ jenis_stok: 'keluar', details: [
    ...f.movement('keluar', '1').details, ...f.movement('keluar', '1', f.items[1]).details,
  ] }, { 'x-client-id': randomUUID() }), 409, 'INSUFFICIENT_STOCK');
  assert.deepEqual(await stockState(f.db), before);
  assert.equal((await f.balance()).saldo, '1');
});

test('outgoing reversal restores exact quantities and permits a separate replacement operation', async (t) => {
  const f = await stockFixture(t);
  assert.equal((await f.post(f.movement('masuk', '0.3'))).statusCode, 201);
  const usage = await f.post(f.movement('keluar', '0.2'));
  assert.equal(usage.statusCode, 201, usage.body);
  const reversal = await f.post({ keterangan: 'Wrong usage' }, {}, `${usage.headers.location}/reverse`);
  assert.equal(reversal.statusCode, 201, reversal.body);
  assert.equal(reversal.json().data.jenis_stok, 'masuk');
  assert.equal(reversal.json().data.reversal_of, usage.json().data.id_stok);
  assert.equal((await f.balance()).saldo, '0.3');
  const replacement = await f.post({ ...f.movement('keluar', '0.1'),
    keterangan: `Replace movement ${usage.json().data.id_stok}` });
  assert.equal(replacement.statusCode, 201, replacement.body);
  assert.equal((await f.balance()).saldo, '0.2');
  assert.equal(replacement.json().data.reversal_of, null);
});
