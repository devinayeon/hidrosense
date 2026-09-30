import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer, password } from '../test-support/fixture.js';
import { requirePermission } from '../src/common/authorization.ts';
import { readConfig } from '../src/config.ts';

test('liveness, database readiness, real HTTP and shutdown work', async (t) => {
  const { app } = await fixture(t);
  assert.equal((await app.inject('/health/live')).json().data.status, 'alive');
  assert.equal((await app.inject('/health/ready')).json().data.status, 'ready');
  const address = await app.listen({ host: '127.0.0.1', port: 0 });
  const response = await fetch(`${address}/health/live`);
  assert.equal(response.status, 200);
  assert.ok(response.headers.get('x-request-id'));
  await response.text();
  await app.close();
  assert.equal(app.server.listening, false);
});

test('readiness returns 503 without leaking database errors', async (t) => {
  const { app, db } = await fixture(t);
  db.close();
  const response = await app.inject('/health/ready');
  assert.equal(response.statusCode, 503);
  assert.equal(response.json().error.code, 'NOT_READY');
  assert.doesNotMatch(response.body, /sqlite|libsql|closed|SELECT/i);
});

test('unknown routes and internal errors share a safe error envelope', async (t) => {
  const { app } = await fixture(t);
  app.get('/test/failure', async () => { throw new Error('SQL secret-password internal-data'); });
  for (const [url, status, code] of [['/missing', 404, 'NOT_FOUND'], ['/test/failure', 500, 'INTERNAL_ERROR']]) {
    const response = await app.inject(url);
    assert.equal(response.statusCode, status);
    assert.equal(response.json().error.code, code);
    assert.equal(response.headers['x-request-id'], response.json().error.request_id);
    assert.doesNotMatch(response.body, /secret-password|internal-data|stack/);
  }
});

test('login rejects empty, unexpected, oversized and malformed payloads', async (t) => {
  const { app } = await fixture(t);
  for (const payload of [{}, { username: '', password }, { username: 'petani', password, role: 'petani' }, { username: 1, password }]) {
    const response = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload });
    assert.equal(response.statusCode, 400);
    assert.equal(response.json().error.code, 'VALIDATION_ERROR');
    assert.doesNotMatch(response.body, /Fixture password/);
  }
  const malformed = await app.inject({ method: 'POST', url: '/api/v1/auth/login', headers: { 'content-type': 'application/json' }, payload: '{bad' });
  assert.equal(malformed.statusCode, 400);
  const oversized = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'a'.repeat(20000), password } });
  assert.equal(oversized.statusCode, 413);
});

test('CORS uses an explicit allowlist; auth responses are not cached', async (t) => {
  const { app, login } = await fixture(t, { env: { CORS_ORIGINS: 'https://console.example' } });
  const allowed = await app.inject({ url: '/health/live', headers: { origin: 'https://console.example' } });
  assert.equal(allowed.headers['access-control-allow-origin'], 'https://console.example');
  const denied = await app.inject({ url: '/health/live', headers: { origin: 'https://other.example' } });
  assert.equal(denied.headers['access-control-allow-origin'], undefined);
  assert.equal((await login()).headers['cache-control'], 'no-store');
  assert.throws(() => readConfig({ CORS_ORIGINS: '*' }), /configuration/i);
  assert.throws(() => readConfig({ PORT: 'banana' }), /configuration/i);
});

test('pegawai may create/read/update panen but cannot access penjualan', async (t) => {
  const { app, db, clock, login } = await fixture(t);
  // Test-only routes prove the reusable guard; business endpoints belong to B15/B16.
  app.get('/test/harvest', { preHandler: requirePermission(db, 'panen:read', clock) }, async () => ({ allowed: true }));
  app.post('/test/harvest', { preHandler: requirePermission(db, 'panen:write', clock) }, async () => ({ allowed: true }));
  app.get('/test/sales', { preHandler: requirePermission(db, 'penjualan:read', clock) }, async () => ({ allowed: true }));
  const token = (await login('pegawai')).json().data.access_token;
  for (const method of ['GET', 'POST']) {
    assert.equal((await app.inject({ method, url: '/test/harvest', headers: bearer(token) })).statusCode, 200);
  }
  assert.equal((await app.inject({ url: '/test/sales', headers: bearer(token) })).statusCode, 403);
  assert.equal((await app.inject('/test/harvest')).statusCode, 401);
  const petani = (await login()).json().data.access_token;
  assert.equal((await app.inject({ url: '/test/sales', headers: bearer(petani) })).statusCode, 200);
});
