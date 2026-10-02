import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

const example = {
  operation_key: '5f9c14e6-76bc-4f68-a3cf-8e4fd877d744', operation_type: 'sync.reserve-id', payload: {},
  resource_type: 'obat', client_id: 'd95fe5e9-8ca7-4bc6-b0d7-3f1c70ab7c2e',
};

test('documented reservation example returns its complete envelope and exact replay', async (t) => {
  const { app, login, db } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const request = { method: 'POST', url: '/api/v1/sync/operations', headers, payload: example };
  const first = await app.inject(request);
  assert.equal(first.statusCode, 201, first.body);
  const result = first.json();
  assert.deepEqual(Object.keys(result).sort(), ['data', 'operation', 'replayed']);
  assert.deepEqual(Object.keys(result.data), ['public_id']);
  assert.deepEqual(Object.keys(result.operation).sort(), ['operation_key', 'public_id', 'revision']);
  assert.match(result.data.public_id, /^[a-f0-9-]{36}$/);
  assert.match(result.operation.revision, /^[1-9][0-9]*$/);
  assert.equal(result.operation.operation_key, example.operation_key);
  assert.equal(result.operation.public_id, result.data.public_id);
  assert.equal(result.replayed, false);
  assert.equal(first.headers['cache-control'], 'no-store');
  assert.ok(first.headers['x-request-id']);
  const replay = await app.inject(request);
  assert.equal(replay.statusCode, 200, replay.body);
  assert.deepEqual(replay.json(), { ...result, replayed: true });
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM sync_resource_versions')).rows[0].n, 0);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM obat')).rows[0].n, 0);
});

test('reservation schema rejects missing or extra fields and documented invalid types', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const invalid = Object.keys(example).map((key) => {
    const body = { ...example }; delete body[key]; return body;
  });
  invalid.push({ ...example, extra: true }, { ...example, payload: { extra: true } },
    { ...example, payload: [] }, { ...example, payload: null },
    { ...example, resource_type: 'Upper' }, { ...example, resource_type: 'a'.repeat(81) },
    { ...example, operation_key: 'bad' }, { ...example, client_id: 'bad' },
    { ...example, operation_type: 'obat.create' });
  for (const payload of invalid) {
    const response = await app.inject({ method: 'POST', url: '/api/v1/sync/operations', headers: { ...headers, 'idempotency-key': example.operation_key }, payload });
    assert.equal(response.statusCode, 400, response.body);
    assert.equal(response.json().error.code, 'VALIDATION_ERROR');
    assert.equal(response.json().error.request_id, response.headers['x-request-id']);
  }
});
