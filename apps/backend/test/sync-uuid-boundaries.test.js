import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

const client = '84c9aa03-e9ea-49ff-bb0b-1f6b0daec6ae';
function canonical(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
}

test('UUID casing preserves reservation, replay, binding and duplicate rejection', async (t) => {
  const { app, login, db } = await fixture(t);
  const headers = bearer((await login('pegawai')).json().data.access_token);
  const payload = { operation_key: randomUUID(), operation_type: 'sync.reserve-id', payload: {}, resource_type: 'obat', client_id: client.toUpperCase() };
  const reserve = (body) => app.inject({ method: 'POST', url: '/api/v1/sync/operations', headers, payload: body });
  const first = await reserve(payload);
  assert.equal(first.statusCode, 201, first.body);
  const replay = await reserve({ ...payload, client_id: client });
  assert.equal(replay.statusCode, 200, replay.body);
  assert.deepEqual(replay.json().data, first.json().data);
  const second = await reserve({ ...payload, operation_key: randomUUID(), client_id: client });
  assert.equal(second.json().data.public_id, first.json().data.public_id);
  const request = { method: 'POST', url: '/api/v1/obat', headers: { ...headers, 'x-client-id': client, 'idempotency-key': randomUUID() }, payload: { nama_obat: 'Canonical' } };
  const created = await app.inject(request);
  assert.equal(created.statusCode, 201, created.body);
  assert.equal(created.json().data.public_id, first.json().data.public_id);
  const repeated = await app.inject({ ...request, headers: { ...request.headers, 'x-client-id': client.toUpperCase() } });
  assert.equal(repeated.statusCode, 200, repeated.body);
  assert.deepEqual(repeated.json().data, created.json().data);
  const duplicate = await app.inject({ ...request, headers: { ...request.headers, 'x-client-id': client.toUpperCase(), 'idempotency-key': randomUUID() } });
  assert.equal(duplicate.statusCode, 409, duplicate.body);
  assert.equal(duplicate.json().error.code, 'RESOURCE_ALREADY_EXISTS');
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM obat')).rows[0].n, 1);
  assert.equal((await db.execute('SELECT client_id FROM sync_id_maps')).rows[0].client_id, client);
});

test('old uppercase mappings and receipt hashes replay without rewriting history', async (t) => {
  const { app, login, db } = await fixture(t);
  const headers = bearer((await login('pegawai')).json().data.access_token);
  const operation_key = randomUUID();
  const payload = { operation_key, operation_type: 'sync.reserve-id', payload: {}, resource_type: 'obat', client_id: client };
  const first = await app.inject({ method: 'POST', url: '/api/v1/sync/operations', headers, payload });
  const oldHash = createHash('sha256').update(canonical({ operation_type: payload.operation_type, payload: {}, resource_type: 'obat', client_id: client.toUpperCase() })).digest('hex');
  await db.execute({ sql: 'UPDATE sync_id_maps SET client_id=?', args: [client.toUpperCase()] });
  await db.execute({ sql: 'UPDATE sync_operations SET payload_hash=? WHERE operation_key=?', args: [oldHash, operation_key] });
  const replay = await app.inject({ method: 'POST', url: '/api/v1/sync/operations', headers, payload });
  assert.equal(replay.statusCode, 200, replay.body);
  assert.deepEqual(replay.json().data, first.json().data);
  const created = await app.inject({ method: 'POST', url: '/api/v1/obat', headers: { ...headers, 'x-client-id': client }, payload: { nama_obat: 'Old mapping' } });
  assert.equal(created.statusCode, 201, created.body);
  assert.equal(created.json().data.public_id, first.json().data.public_id);
  assert.equal((await db.execute('SELECT client_id FROM sync_id_maps')).rows[0].client_id, client.toUpperCase());
  assert.equal((await db.execute({ sql: 'SELECT payload_hash FROM sync_operations WHERE operation_key=?', args: [operation_key] })).rows[0].payload_hash, oldHash);
});

test('conflicting historical case mappings fail closed without mutation', async (t) => {
  const { app, login, db } = await fixture(t);
  const headers = bearer((await login('pegawai')).json().data.access_token);
  const actor = (await db.execute("SELECT CAST(id_user AS TEXT) AS id FROM users WHERE username='pegawai'")).rows[0].id;
  for (const spelling of [client, client.toUpperCase()]) {
    await db.execute({ sql: 'INSERT INTO sync_id_maps(id_user,resource_type,client_id,public_id,created_at) VALUES (?,?,?,?,0)', args: [actor, 'obat', spelling, randomUUID()] });
  }
  const response = await app.inject({ method: 'POST', url: '/api/v1/obat', headers: { ...headers, 'x-client-id': client }, payload: { nama_obat: 'Collision' } });
  assert.equal(response.statusCode, 409, response.body);
  assert.equal(response.json().error.code, 'CLIENT_ID_CONFLICT');
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM obat')).rows[0].n, 0);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM sync_operations')).rows[0].n, 0);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM sync_id_maps')).rows[0].n, 2);
});

test('historical domain receipt with uppercase client UUID replays after canonicalization', async (t) => {
  const { app, login, db } = await fixture(t);
  const headers = { ...bearer((await login('pegawai')).json().data.access_token), 'x-client-id': client, 'idempotency-key': randomUUID() };
  const payload = { nama_obat: 'Historical create' };
  const request = { method: 'POST', url: '/api/v1/obat', headers, payload };
  const first = await app.inject(request);
  assert.equal(first.statusCode, 201, first.body);
  const oldHash = createHash('sha256').update(canonical({ operation_type: 'obat.create', payload, resource_type: 'obat', client_id: client.toUpperCase() })).digest('hex');
  await db.execute({ sql: 'UPDATE sync_id_maps SET client_id=?', args: [client.toUpperCase()] });
  await db.execute({ sql: 'UPDATE sync_operations SET payload_hash=? WHERE operation_key=?', args: [oldHash, headers['idempotency-key']] });
  const replay = await app.inject(request);
  assert.equal(replay.statusCode, 200, replay.body);
  assert.deepEqual(replay.json().data, first.json().data);
  const conflict = await app.inject({ ...request, payload: { nama_obat: 'Different' } });
  assert.equal(conflict.statusCode, 409, conflict.body);
  assert.equal(conflict.json().error.code, 'OPERATION_CONFLICT');
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM obat')).rows[0].n, 1);
  assert.equal((await db.execute('SELECT version FROM sync_resource_versions')).rows[0].version, 1);
});
