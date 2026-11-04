// The API is deployed as serverless functions: no listen(), no stable proxy IP, many instances.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { test } from 'node:test';
import { buildApp } from '../src/app.ts';
import { readConfig } from '../src/config.ts';
import { openDatabase } from '../src/db/client.ts';
import { loadMigrations, migrate } from '../src/db/migrate.ts';
import { createHandler, openServerlessApp } from '../src/serverless.ts';
import { fixture, password } from '../test-support/fixture.js';

async function memoryApp(t, env = {}) {
  const db = await openDatabase({ url: ':memory:' });
  await migrate(db, await loadMigrations());
  const app = buildApp({ db, config: readConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent', ...env }) });
  await app.ready();
  t.after(() => app.close());
  return app;
}

async function serve(t, handler) {
  const server = createServer(handler);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); }));
  return `http://127.0.0.1:${server.address().port}`;
}

test('the handler serves requests without the app ever listening', async (t) => {
  const app = await memoryApp(t);
  const base = await serve(t, createHandler(async () => app));
  const live = await fetch(`${base}/health/live`);
  assert.equal(live.status, 200);
  assert.deepEqual(await live.json(), { data: { status: 'alive' } });
  assert.ok(live.headers.get('x-request-id'));
  assert.equal(app.server.listening, false);

  // A request body must survive the hand-over to Fastify.
  const login = await fetch(`${base}/api/v1/auth/login`, { method: 'POST',
    headers: { 'content-type': 'application/json' }, body: JSON.stringify({ username: 'tidak-ada', password: 'x' }) });
  assert.equal(login.status, 401);
  assert.equal((await login.json()).error.code, 'INVALID_CREDENTIALS');
});

test('a cold start opens one app even when requests arrive together', async (t) => {
  const app = await memoryApp(t);
  let opens = 0;
  const base = await serve(t, createHandler(async () => {
    opens += 1;
    await new Promise(setImmediate);
    return app;
  }));
  const responses = await Promise.all(Array.from({ length: 5 }, () => fetch(`${base}/health/live`)));
  assert.deepEqual(responses.map((response) => response.status), [200, 200, 200, 200, 200]);
  assert.equal(opens, 1);
});

test('a failed cold start answers 503 without detail, then recovers', async (t) => {
  const app = await memoryApp(t);
  let opens = 0;
  const base = await serve(t, createHandler(async () => {
    opens += 1;
    if (opens === 1) throw new Error('libsql://rahasia.turso.io token=abc');
    return app;
  }));
  const failed = await fetch(`${base}/health/live`);
  const text = await failed.text();
  assert.equal(failed.status, 503);
  assert.equal(failed.headers.get('cache-control'), 'no-store');
  assert.equal(failed.headers.get('retry-after'), '1');
  const { error } = JSON.parse(text);
  assert.equal(error.code, 'NOT_READY');
  assert.equal(error.request_id, failed.headers.get('x-request-id'));
  assert.equal(text.includes('rahasia'), false);
  assert.equal((await fetch(`${base}/health/live`)).status, 200);
  assert.equal(opens, 2);
});

function withEnv(t, env) {
  const saved = { ...process.env };
  for (const key of ['DATABASE_URL', 'NODE_ENV', 'TRUST_PROXY_HOPS', 'TRUSTED_PROXIES']) delete process.env[key];
  Object.assign(process.env, env);
  t.after(() => {
    for (const key of Object.keys(process.env)) if (!(key in saved)) delete process.env[key];
    Object.assign(process.env, saved);
  });
}

test('a function refuses a local database: its filesystem does not persist', async (t) => {
  for (const url of [undefined, 'file:./data/hidrosense.db', ':memory:']) {
    withEnv(t, { NODE_ENV: 'production', TRUST_PROXY_HOPS: '1', ...(url ? { DATABASE_URL: url } : {}) });
    await assert.rejects(openServerlessApp(), /DATABASE_URL/);
  }
});

test('a local database is allowed while developing', async (t) => {
  withEnv(t, { NODE_ENV: 'development', DATABASE_URL: ':memory:', LOG_LEVEL: 'silent' });
  const app = await openServerlessApp();
  t.after(() => app.close());
  assert.equal((await app.inject({ url: '/health/live' })).statusCode, 200);
});

test('production refuses to start without knowing its proxy, instead of answering 426 forever', async (t) => {
  withEnv(t, { NODE_ENV: 'production', DATABASE_URL: 'libsql://contoh.invalid' });
  await assert.rejects(openServerlessApp(), /TRUST_PROXY_HOPS/);
});

test('TRUST_PROXY_HOPS is validated and excludes TRUSTED_PROXIES', () => {
  assert.equal(readConfig({}).proxyHops, undefined);
  assert.equal(readConfig({ TRUST_PROXY_HOPS: '2' }).proxyHops, 2);
  for (const value of ['0', '-1', 'true', '1.5', '100', ' ']) {
    assert.throws(() => readConfig({ TRUST_PROXY_HOPS: value }), /TRUST_PROXY_HOPS/, value);
  }
  assert.throws(() => readConfig({ TRUST_PROXY_HOPS: '1', TRUSTED_PROXIES: '10.0.0.1' }), /TRUST_PROXY_HOPS/);
});

const hops = { NODE_ENV: 'production', TRUST_PROXY_HOPS: '1' };
const viaProxy = (client, extra = {}) => ({ url: '/api/v1/auth/me', headers: {
  'x-forwarded-proto': 'https', 'x-forwarded-for': client, ...extra } });

test('behind one proxy, production accepts forwarded HTTPS and refuses plain HTTP', async (t) => {
  const { app } = await fixture(t, { env: hops });
  assert.equal((await app.inject(viaProxy('203.0.113.9'))).statusCode, 401);
  const plain = await app.inject({ url: '/api/v1/auth/me', headers: { 'x-forwarded-proto': 'http', 'x-forwarded-for': '203.0.113.9' } });
  assert.equal(plain.statusCode, 426);
});

test('each client has its own quota behind the proxy; one client cannot exhaust the others', async (t) => {
  const { app } = await fixture(t, { env: hops });
  for (let i = 0; i < 120; i += 1) await app.inject(viaProxy('203.0.113.9'));
  assert.equal((await app.inject(viaProxy('203.0.113.9'))).statusCode, 429);
  assert.equal((await app.inject(viaProxy('203.0.113.10'))).statusCode, 401);
});

test('a client cannot escape its quota by forging X-Forwarded-For', async (t) => {
  const { app } = await fixture(t, { env: hops });
  for (let i = 0; i < 120; i += 1) await app.inject(viaProxy(`198.51.100.${i % 250}, 203.0.113.9`));
  assert.equal((await app.inject(viaProxy('198.51.100.251, 203.0.113.9'))).statusCode, 429);
});

test('the login quota follows the real client too', async (t) => {
  const { app } = await fixture(t, { env: hops });
  const attempt = (client) => app.inject({ method: 'POST', url: '/api/v1/auth/login',
    headers: { 'x-forwarded-proto': 'https', 'x-forwarded-for': client },
    payload: { username: 'petani', password: 'salah-sekali' } });
  for (let i = 0; i < 10; i += 1) assert.equal((await attempt('203.0.113.9')).statusCode, 401);
  assert.equal((await attempt('203.0.113.9')).statusCode, 429);
  // The farmer on another address can still sign in while the attacker is throttled.
  const owner = await app.inject({ method: 'POST', url: '/api/v1/auth/login',
    headers: { 'x-forwarded-proto': 'https', 'x-forwarded-for': '203.0.113.50' },
    payload: { username: 'petani', password } });
  assert.equal(owner.statusCode, 200, owner.body);
});

test('the IP quota is shared across function instances', async (t) => {
  const { app, db, config, clock } = await fixture(t, { env: hops });
  const other = buildApp({ db, config, clock });
  t.after(() => other.close());
  for (let i = 0; i < 120; i += 1) await (i % 2 ? app : other).inject(viaProxy('203.0.113.9'));
  assert.equal((await other.inject(viaProxy('203.0.113.9'))).statusCode, 429);
});
