import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { bearer } from '../test-support/fixture.js';
import { stockFixture, expectError, stockState } from '../test-support/stock-fixture.js';
import { recordMovement } from '../src/features/stock/service.ts';

test('stock requires caller operation keys and validates optional client UUID', async (t) => {
  const f = await stockFixture(t);
  for (const extra of [{}, { 'idempotency-key': 'bad' },
    { 'idempotency-key': randomUUID(), 'x-client-id': 'bad' }]) {
    const response = await f.app.inject({ method: 'POST', url: '/api/v1/stok',
      headers: { ...f.headers, ...extra }, payload: f.movement() });
    expectError(response, 400, 'VALIDATION_ERROR');
  }
  assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM stok')).rows[0].n, 0);
});

test('response-loss retry canonicalizes lines, amounts, labels, optional reason and UUID casing', async (t) => {
  const f = await stockFixture(t);
  const clientId = randomUUID();
  const headers = { ...f.headers, 'idempotency-key': randomUUID(), 'x-client-id': clientId.toUpperCase() };
  const payload = { jenis_stok: 'masuk', details: [
    { id_inventaris: f.items[1].id_inventaris, jumlah: '002.00', satuan: ' kg ' },
    { id_inventaris: f.items[0].id_inventaris, jumlah: '0.10', satuan: 'kg' },
  ] };
  const first = await f.app.inject({ method: 'POST', url: '/api/v1/stok', headers, payload });
  assert.equal(first.statusCode, 201, first.body);
  const before = await stockState(f.db);
  const replay = await f.app.inject({ method: 'POST', url: '/api/v1/stok',
    headers: { ...headers, 'x-client-id': clientId },
    payload: { jenis_stok: 'masuk', keterangan: null, details: [
      { id_inventaris: f.items[0].id_inventaris, jumlah: '0.1', satuan: 'kg' },
      { id_inventaris: f.items[1].id_inventaris, jumlah: '2', satuan: 'kg' },
    ] } });
  assert.equal(replay.statusCode, 200, replay.body);
  assert.deepEqual(replay.json(), { ...first.json(), replayed: true });
  assert.deepEqual(await stockState(f.db), before);
  assert.equal((await f.balance()).saldo, '0.1');
  await f.app.inject({ method: 'POST', url: `/api/v1/inventaris/${f.items[0].id_inventaris}/deactivate`, headers: f.headers });
  const afterDeactivate = await f.app.inject({ method: 'POST', url: '/api/v1/stok', headers, payload });
  assert.equal(afterDeactivate.statusCode, 200, afterDeactivate.body);
  assert.deepEqual(afterDeactivate.json().data, first.json().data);
});

test('stock binds reserved UUID once and operation key rejects changed payload/type/client identity', async (t) => {
  const f = await stockFixture(t);
  const clientId = randomUUID();
  const reserved = await f.app.inject({ method: 'POST', url: '/api/v1/sync/operations', headers: f.headers,
    payload: { operation_key: randomUUID(), operation_type: 'sync.reserve-id', payload: {},
      resource_type: 'stok', client_id: clientId } });
  assert.equal(reserved.statusCode, 201, reserved.body);
  const headers = { 'idempotency-key': randomUUID(), 'x-client-id': clientId };
  const first = await f.post(f.movement(), headers);
  assert.equal(first.statusCode, 201, first.body);
  assert.equal(first.json().data.public_id, reserved.json().data.public_id);
  assert.equal(first.json().operation.public_id, reserved.json().data.public_id);
  assert.equal(first.json().operation.version, '1');
  expectError(await f.post(f.movement('masuk', '2'), headers), 409, 'OPERATION_CONFLICT');
  expectError(await f.post(f.movement(), { ...headers, 'x-client-id': randomUUID() }), 409, 'OPERATION_CONFLICT');
  expectError(await f.post({ keterangan: 'Correction' }, headers, `${first.headers.location}/reverse`), 409, 'OPERATION_CONFLICT');
  expectError(await f.post(f.movement(), { ...headers, 'idempotency-key': randomUUID() }), 409, 'RESOURCE_ALREADY_EXISTS');
  assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM stok')).rows[0].n, 1);
});

test('stock operation keys retain exact casing and actor namespaces are independent', async (t) => {
  const f = await stockFixture(t);
  const key = 'abcdefab-abcd-4abc-8abc-abcdefabcdef';
  assert.equal((await f.post(f.movement(), { 'idempotency-key': key })).statusCode, 201);
  assert.equal((await f.post(f.movement(), { 'idempotency-key': key.toUpperCase() })).statusCode, 201);
  await f.db.execute("INSERT INTO users (id_role,nama,username,password) SELECT id_role,'Other','other',password FROM users WHERE id_user=2");
  const login = await f.login('other');
  assert.equal(login.statusCode, 200, login.body);
  const response = await f.app.inject({ method: 'POST', url: '/api/v1/stok',
    headers: { ...bearer(login.json().data.access_token), 'idempotency-key': key }, payload: f.movement() });
  assert.equal(response.statusCode, 201, response.body);
  assert.equal(response.json().data.id_user, '3');
  assert.equal((await f.balance()).saldo, '3');
});

test('reversal retry returns saved identity and does not repeat balance effects', async (t) => {
  const f = await stockFixture(t);
  const receipt = await f.post(f.movement('masuk', '0.20'));
  const headers = { 'idempotency-key': randomUUID(), 'x-client-id': randomUUID() };
  const first = await f.post({ keterangan: ' Correction ' }, headers, `${receipt.headers.location}/reverse`);
  assert.equal(first.statusCode, 201, first.body);
  const before = await stockState(f.db);
  const replay = await f.post({ keterangan: 'Correction' }, headers, `${receipt.headers.location}/reverse`);
  assert.equal(replay.statusCode, 200, replay.body);
  assert.deepEqual(replay.json(), { ...first.json(), replayed: true });
  assert.deepEqual(await stockState(f.db), before);
  assert.equal((await f.balance()).saldo, '0');
});

test('detail, seal, mapping, identity, version and receipt failures roll back all stock effects', async (t) => {
  const f = await stockFixture(t);
  const cases = [
    ['detail', 'BEFORE INSERT ON detail_stok'],
    ['seal', 'BEFORE UPDATE OF sealed ON stok WHEN NEW.sealed=1'],
    ['mapping', 'BEFORE INSERT ON sync_id_maps'],
    ['identity', "BEFORE INSERT ON sync_resource_links WHEN NEW.resource_type='stok'"],
    ['version', "BEFORE INSERT ON sync_resource_versions WHEN NEW.resource_type='stok'"],
    ['receipt', "BEFORE INSERT ON sync_operations WHEN NEW.operation_type='stok.create'"],
  ];
  for (const [name, clause] of cases) {
    const before = await stockState(f.db);
    await f.db.execute(`CREATE TRIGGER fail_stock_${name} ${clause} BEGIN SELECT RAISE(ABORT,'injected failure'); END`);
    const headers = { 'idempotency-key': randomUUID(), 'x-client-id': randomUUID() };
    const payload = { jenis_stok: 'masuk', details: [
      ...f.movement('masuk', '0.1').details, ...f.movement('masuk', '0.2', f.items[1]).details,
    ] };
    const response = await f.post(payload, headers);
    expectError(response, 500, 'INTERNAL_ERROR');
    assert.doesNotMatch(response.body, /injected failure|INSERT INTO|CREATE TRIGGER/);
    assert.deepEqual(await stockState(f.db), before, name);
    await f.db.execute(`DROP TRIGGER fail_stock_${name}`);
    const retry = await f.post(payload, headers);
    assert.equal(retry.statusCode, 201, `${name}: ${retry.body}`);
    const replay = await f.post(payload, headers);
    assert.equal(replay.statusCode, 200, replay.body);
  }
});

test('sealed stock forbids SQL mutation, deletion and late detail insertion', async (t) => {
  const f = await stockFixture(t);
  const created = await f.post(f.movement());
  assert.equal(created.statusCode, 201, created.body);
  const id = created.json().data.id_stok;
  const detail = created.json().data.details[0].id_detail_stok;
  const before = await stockState(f.db);
  for (const [sql, args] of [
    ['UPDATE stok SET keterangan=? WHERE id_stok=?', ['changed', id]],
    ['UPDATE stok SET sealed=0 WHERE id_stok=?', [id]],
    ['DELETE FROM stok WHERE id_stok=?', [id]],
    ['UPDATE detail_stok SET jumlah_minor=2 WHERE id_detail_stok=?', [detail]],
    ['DELETE FROM detail_stok WHERE id_detail_stok=?', [detail]],
    ['INSERT INTO detail_stok (id_stok,id_inventaris,jumlah,jumlah_minor,satuan) VALUES (?,?,1,100,?)',
      [id, f.items[1].id_inventaris, 'kg']],
    ['UPDATE inventaris SET satuan=? WHERE id_inventaris=?', ['ml', f.items[0].id_inventaris]],
  ]) await assert.rejects(f.db.execute({ sql, args }));
  assert.deepEqual(await stockState(f.db), before);
});

test('stock signed64 item, movement and detail IDs survive number-mode transport unchanged', async (t) => {
  const f = await stockFixture(t);
  const itemId = '9007199254740993';
  await f.db.execute({ sql: `INSERT INTO inventaris (id_inventaris,id_jenis_inventaris,nama_barang,satuan)
    SELECT CAST(? AS INTEGER),id_jenis_inventaris,'large','kg' FROM inventaris WHERE id_inventaris=?`,
    args: [itemId, f.items[0].id_inventaris] });
  const first = await f.post(f.movement());
  assert.equal(first.statusCode, 201, first.body);
  await f.db.execute("UPDATE sqlite_sequence SET seq=9007199254740992 WHERE name IN ('stok','detail_stok')");
  const created = await f.post(f.movement('masuk', '0.01', { id_inventaris: itemId, satuan: 'kg' }));
  assert.equal(created.statusCode, 201, created.body);
  const data = created.json().data;
  assert.equal(data.id_stok, itemId);
  assert.equal(data.details[0].id_detail_stok, itemId);
  assert.equal(data.details[0].id_inventaris, itemId);
  assert.equal((await f.balance({ id_inventaris: itemId })).saldo, '0.01');
  assert.deepEqual((await f.app.inject({ url: created.headers.location, headers: f.headers })).json().data, data);
  const list = await f.app.inject({ url: `/api/v1/stok?id_inventaris=${itemId}`, headers: f.headers });
  assert.deepEqual(list.json().data, [data]);
});

test('generic stock routes reject reversal of domain-linked consumption', async (t) => {
  const f = await stockFixture(t);
  assert.equal((await f.post(f.movement('masuk', '2'))).statusCode, 201);
  // The owning B007 domain creates its source record before consuming stock.
  await f.db.execute("INSERT INTO penyemaian (id_user,tanggal_semai,jumlah_benih) VALUES (2,'2026-10-03',1)");
  const origin = String((await f.db.execute('SELECT last_insert_rowid() AS id')).rows[0].id);
  const tx = await f.db.transaction('write');
  let linked;
  try {
    linked = await recordMovement(tx, '2', f.clock(), f.movement('keluar', '1'), { id_penyemaian: origin });
    await tx.commit();
  } finally { if (!tx.closed) await tx.rollback(); tx.close(); }
  assert.match(linked.public_id, /^[0-9a-f-]{36}$/);
  assert.equal(linked.version, '1');
  const linkedDetail = await f.app.inject({ url: `/api/v1/stok/${linked.id_stok}`, headers: f.headers });
  assert.equal(linkedDetail.json().data.public_id, linked.public_id);
  assert.equal(linkedDetail.json().data.version, '1');
  expectError(await f.post({ keterangan: 'Generic correction forbidden' }, {},
    `/api/v1/stok/${linked.id_stok}/reverse`), 409, 'REVERSAL_NOT_ALLOWED');
  assert.equal((await f.balance()).saldo, '1');
  const before = await stockState(f.db);
  const duplicateTx = await f.db.transaction('write');
  try {
    await assert.rejects(recordMovement(duplicateTx, '2', f.clock(),
      f.movement('keluar', '1'), { id_penyemaian: origin }));
  } finally { if (!duplicateTx.closed) await duplicateTx.rollback(); duplicateTx.close(); }
  assert.deepEqual(await stockState(f.db), before);
});
