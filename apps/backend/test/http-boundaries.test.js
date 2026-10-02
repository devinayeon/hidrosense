import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture } from '../test-support/fixture.js';

const preflight = { method: 'OPTIONS', url: '/api/v1/auth/login', headers: {
  origin: 'https://console.example', 'access-control-request-method': 'POST',
} };

function assertEnvelope(response, status, code) {
  assert.equal(response.statusCode, status, response.body);
  assert.equal(response.json().error.code, code);
  assert.equal(response.json().error.request_id, response.headers['x-request-id']);
  assert.ok(response.headers['x-request-id']);
  assert.equal(response.headers['cache-control'], 'no-store');
}

test('production preflight requires verified HTTPS before CORS can terminate', async (t) => {
  const { app, db } = await fixture(t, { env: { NODE_ENV: 'production', CORS_ORIGINS: 'https://console.example' } });
  assertEnvelope(await app.inject(preflight), 426, 'HTTPS_REQUIRED');
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM auth_rate_limits')).rows[0].n, 0);
});

test('HTTPS preflight has universal headers, origin policy and global throttling', async (t) => {
  const { app, db } = await fixture(t, { env: {
    NODE_ENV: 'production', CORS_ORIGINS: 'https://console.example', TRUSTED_PROXIES: '127.0.0.1',
  } });
  const request = { ...preflight, headers: { ...preflight.headers, 'x-forwarded-proto': 'https' } };
  for (let i = 0; i < 120; i++) {
    const response = await app.inject(request);
    assert.equal(response.statusCode, 204, response.body);
    assert.equal(response.headers['access-control-allow-origin'], 'https://console.example');
    assert.ok(response.headers['x-request-id']);
    assert.equal(response.headers['cache-control'], 'no-store');
  }
  const limited = await app.inject(request);
  assertEnvelope(limited, 429, 'RATE_LIMITED');
  assert.ok(Number(limited.headers['retry-after']) > 0);
  assert.equal(limited.headers['access-control-allow-origin'], 'https://console.example');
  assert.match(limited.headers['access-control-expose-headers'], /Retry-After/);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM auth_rate_limits')).rows[0].n, 1);
});

test('allowed-origin actual requests retain CORS access to throttle errors', async (t) => {
  const { app } = await fixture(t, { env: { CORS_ORIGINS: 'https://console.example' } });
  const request = { url: '/api/v1/auth/me', headers: { origin: 'https://console.example' } };
  for (let i = 0; i < 120; i++) {
    assert.equal((await app.inject(request)).statusCode, 401);
  }
  const limited = await app.inject(request);
  assertEnvelope(limited, 429, 'RATE_LIMITED');
  assert.equal(limited.headers['access-control-allow-origin'], 'https://console.example');
  assert.match(limited.headers['access-control-expose-headers'], /Retry-After/);
  assert.ok(Number(limited.headers['retry-after']) > 0);
});

test('incomplete preflight uses the shared error envelope', async (t) => {
  const { app } = await fixture(t, { env: { CORS_ORIGINS: 'https://console.example' } });
  for (const headers of [{}, { origin: 'https://console.example' }, { 'access-control-request-method': 'POST' }]) {
    assertEnvelope(await app.inject({ ...preflight, headers }), 400, 'BAD_REQUEST');
  }
});
