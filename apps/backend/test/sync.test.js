import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { bearer, fixture } from '../test-support/fixture.js';
import { nextResourceVersion } from '../src/common/sync.ts';

async function submit(app, token, payload) {
  return app.inject({ method: 'POST', url: '/api/v1/sync/operations', headers: bearer(token), payload });
}

test('sync operation creates one durable receipt and replays its exact result', async (t) => {
  const { app, login, db } = await fixture(t);
  const token = (await login()).json().data.access_token;
  const operation_key = randomUUID();
  const first = await submit(app, token, { operation_key, operation_type: 'inventaris.create', payload: { name: 'A', quantity: 1 } });
  const replay = await submit(app, token, { operation_key, operation_type: 'inventaris.create', payload: { quantity: 1, name: 'A' } });
  assert.equal(first.statusCode, 201);
  assert.equal(replay.statusCode, 200);
  assert.deepEqual(replay.json().data, first.json().data);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM sync_operations')).rows[0].n, 1);
});

test('sync rejects a reused key with different content and isolates keys by actor', async (t) => {
  const { app, login, db } = await fixture(t);
  const key = randomUUID();
  const petani = (await login()).json().data.access_token;
  assert.equal((await submit(app, petani, { operation_key: key, operation_type: 'inventaris.create', payload: { name: 'A' } })).statusCode, 201);
  const conflict = await submit(app, petani, { operation_key: key, operation_type: 'inventaris.create', payload: { name: 'B' } });
  assert.equal(conflict.statusCode, 409);
  assert.equal(conflict.json().error.code, 'OPERATION_CONFLICT');
  const pegawai = (await login('pegawai')).json().data.access_token;
  assert.equal((await submit(app, pegawai, { operation_key: key, operation_type: 'inventaris.create', payload: { name: 'A' } })).statusCode, 201);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM sync_operations')).rows[0].n, 2);
});

test('sync maps a client UUID to one stable public UUID and validates its contract', async (t) => {
  const { app, login } = await fixture(t);
  const token = (await login()).json().data.access_token;
  const client_id = randomUUID();
  const request = (operation_key) => ({ operation_key, operation_type: 'inventaris.create', payload: {}, resource_type: 'inventaris', client_id });
  const first = await submit(app, token, request(randomUUID()));
  const second = await submit(app, token, request(randomUUID()));
  assert.equal(first.statusCode, 201);
  assert.equal(first.json().data.public_id, second.json().data.public_id);
  assert.equal((await submit(app, token, { operation_key: randomUUID(), operation_type: 'Bad', payload: {} })).statusCode, 400);
  assert.equal((await submit(app, token, { operation_key: randomUUID(), operation_type: 'inventaris.create', payload: {}, resource_type: 'inventaris' })).statusCode, 400);
  assert.equal((await submit(app, undefined, request(randomUUID()))).statusCode, 401);
});

test('resource versions increase atomically for a public ID', async (t) => {
  const { db, clock } = await fixture(t);
  const tx = await db.transaction('write');
  try {
    const id = randomUUID();
    assert.equal(await nextResourceVersion(tx, 'inventaris', id, clock()), '1');
    assert.equal(await nextResourceVersion(tx, 'inventaris', id, clock()), '2');
    await tx.commit();
  } finally { tx.close(); }
});
