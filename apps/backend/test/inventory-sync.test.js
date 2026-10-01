import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

test('reserved identity binds to domain writes; replay never increments resource version', async (t) => {
  const { app, login, db } = await fixture(t);
  const headers = bearer((await login('pegawai')).json().data.access_token);
  const clientId = randomUUID();
  const reserved = await app.inject({ method: 'POST', url: '/api/v1/sync/operations', headers,
    payload: { operation_key: randomUUID(), operation_type: 'sync.reserve-id', payload: {}, resource_type: 'obat', client_id: clientId } });
  const createHeaders = { ...headers, 'x-client-id': clientId, 'idempotency-key': randomUUID() };
  const request = { method: 'POST', url: '/api/v1/obat', headers: createHeaders, payload: { nama_obat: 'A' } };
  const first = await app.inject(request);
  assert.equal(first.statusCode, 201, first.body);
  assert.equal(first.json().data.public_id, reserved.json().data.public_id);
  assert.equal(first.json().data.version, '1');
  const replay = await app.inject(request);
  assert.equal(replay.statusCode, 200, replay.body);
  assert.deepEqual(replay.json().data, first.json().data);
  const duplicate = await app.inject({ ...request, headers: { ...createHeaders, 'idempotency-key': randomUUID() } });
  assert.equal(duplicate.statusCode, 409, duplicate.body);
  const edit = { method: 'PATCH', url: first.headers.location, headers: { ...headers, 'idempotency-key': randomUUID() }, payload: { nama_obat: 'B' } };
  const updated = await app.inject(edit);
  assert.equal(updated.json().data.version, '2');
  assert.equal(updated.json().operation.public_id, first.json().data.public_id);
  assert.equal((await app.inject(edit)).json().data.version, '2');
  const detail = await app.inject({ url: first.headers.location, headers });
  assert.deepEqual(detail.json().data, updated.json().data);
  const deactivated = await app.inject({ method: 'POST', url: `${first.headers.location}/deactivate`, headers });
  assert.equal(deactivated.json().data.version, '3');
  assert.equal((await db.execute('SELECT version FROM sync_resource_versions')).rows[0].version, 3);
});

test('receipt failure rolls back mutation, resource identity and version', async (t) => {
  const { app, login, db } = await fixture(t);
  const headers = bearer((await login('pegawai')).json().data.access_token);
  await db.execute("CREATE TRIGGER fail_receipt BEFORE INSERT ON sync_operations BEGIN SELECT RAISE(ABORT,'failure'); END");
  const response = await app.inject({ method: 'POST', url: '/api/v1/obat', headers, payload: { nama_obat: 'Rollback' } });
  assert.equal(response.statusCode, 500);
  for (const table of ['obat', 'sync_resource_links', 'sync_resource_versions', 'sync_operations']) {
    assert.equal((await db.execute(`SELECT COUNT(*) AS n FROM ${table}`)).rows[0].n, 0);
  }
});

test('legacy domain receipts replay their original result after the identity upgrade', async (t) => {
  const { app, login, db } = await fixture(t);
  const headers = { ...bearer((await login('pegawai')).json().data.access_token), 'idempotency-key': randomUUID() };
  const payload = { nama_obat: 'Legacy receipt' };
  const first = await app.inject({ method: 'POST', url: '/api/v1/obat', headers, payload });
  const legacyHash = createHash('sha256').update(JSON.stringify({ operation_type: 'obat.create', payload })).digest('hex');
  await db.execute({ sql: 'UPDATE sync_operations SET payload_hash=? WHERE operation_key=?', args: [legacyHash, headers['idempotency-key']] });
  const replay = await app.inject({ method: 'POST', url: '/api/v1/obat', headers, payload });
  assert.equal(replay.statusCode, 200, replay.body);
  assert.deepEqual(replay.json().data, first.json().data);
  assert.equal((await db.execute('SELECT version FROM sync_resource_versions')).rows[0].version, 1);
});
