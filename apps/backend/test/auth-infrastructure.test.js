import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { buildApp } from '../src/app.ts';
import { readConfig } from '../src/config.ts';
import { bootstrapPetani } from '../src/features/auth/bootstrap.ts';
import { verifyPassword } from '../src/common/passwords.ts';
import { consumeLimit } from '../src/common/rate-limit.ts';
import { fixture, bearer, password } from '../test-support/fixture.js';

test('auth migration upgrades and rolls back without changing original users or roles', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const migrations = await loadMigrations();
  await migrate(db, migrations.slice(0, 1));
  await db.execute("INSERT INTO roles (nama_role) VALUES ('petani')");
  await db.execute("INSERT INTO users (id_role,nama,username,password) VALUES (1,'Existing','existing','legacy-hash')");
  const before = (await db.execute('SELECT * FROM users')).rows;
  await migrate(db, migrations);
  assert.deepEqual((await db.execute('SELECT * FROM users')).rows, before);
  await assert.rejects(db.execute(`INSERT INTO auth_sessions VALUES ('a',999,'b','c','d',1,2,3)`), /FOREIGN KEY/);
  await migrate(db, migrations, { direction: 'down', allowDataLoss: true });
  assert.deepEqual((await db.execute('SELECT * FROM users')).rows, before);
  assert.equal((await db.execute("SELECT COUNT(*) AS n FROM sqlite_master WHERE name='auth_sessions'")).rows[0].n, 0);
  await migrate(db, migrations);
  assert.deepEqual((await db.execute('PRAGMA foreign_key_check')).rows, []);
});

test('bootstrap creates the first petani with a hash and never replaces an existing account', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  await migrate(db, await loadMigrations());
  await assert.rejects(bootstrapPetani(db, { username: 'first', nama: 'Petani', password: 'short' }), /12/);
  const user = await bootstrapPetani(db, { username: 'first', nama: 'Petani', password });
  assert.equal(user.id_user, '1');
  const stored = (await db.execute('SELECT password FROM users')).rows[0].password;
  assert.notEqual(stored, password);
  assert.ok(await verifyPassword(password, stored));
  await assert.rejects(bootstrapPetani(db, { username: 'second', nama: 'Petani lain', password }), /sudah ada/);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM users')).rows[0].n, 1);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM roles')).rows[0].n, 2);
});

test('bootstrap duplicate username rolls back without creating partial roles', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  await migrate(db, await loadMigrations());
  await db.execute("INSERT INTO roles (nama_role) VALUES ('pegawai')");
  await db.execute("INSERT INTO users (id_role,nama,username,password) VALUES (1,'Existing','first','hash')");
  await assert.rejects(bootstrapPetani(db, { username: 'first', nama: 'Petani', password }), /digunakan/);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM roles')).rows[0].n, 1);
});

test('database rate limits survive separate app instances and reset after their window', async (t) => {
  const { app, db, config, clock, advance } = await fixture(t);
  const secondApp = buildApp({ db, config, clock });
  t.after(() => secondApp.close());
  for (let i = 0; i < 120; i++) {
    const server = i % 2 ? app : secondApp;
    assert.equal((await server.inject('/api/v1/auth/me')).statusCode, 401);
  }
  const limited = await secondApp.inject('/api/v1/auth/me');
  assert.equal(limited.statusCode, 429);
  assert.equal(limited.json().error.code, 'RATE_LIMITED');
  assert.equal(limited.headers['retry-after'], '60');
  // Untrusted forwarded headers cannot bypass the IP bucket.
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: { 'x-forwarded-for': '192.0.2.99' } })).statusCode, 429);
  advance(60000);
  assert.equal((await app.inject('/api/v1/auth/me')).statusCode, 401);
});

test('account throttle returns 429 before deriving another password', async (t) => {
  const { app, db, clock } = await fixture(t);
  const reply = { header() { return this; } };
  for (let i = 0; i < 10; i++) await consumeLimit(db, 'login:petani', 10, 900000, clock(), reply);
  const response = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'petani', password } });
  assert.equal(response.statusCode, 429);
  assert.equal(response.headers['retry-after'], '900');
});

test('production requires HTTPS and trusts forwarded protocol only from configured proxies', async (t) => {
  const { app } = await fixture(t, { env: { NODE_ENV: 'production' } });
  const spoofed = await app.inject({ url: '/api/v1/auth/me', headers: { 'x-forwarded-proto': 'https' } });
  assert.equal(spoofed.statusCode, 426);
  const trusted = await fixture(t, { env: { NODE_ENV: 'production', TRUSTED_PROXIES: '127.0.0.1/32' } });
  assert.equal((await trusted.app.inject({ url: '/api/v1/auth/me', headers: { 'x-forwarded-proto': 'https' } })).statusCode, 401);
  assert.throws(() => readConfig({ TRUSTED_PROXIES: 'true' }), /configuration/);
  assert.throws(() => readConfig({ NODE_ENV: 'production', CORS_ORIGINS: 'http://console.example' }), /configuration/);
});

test('password changes invalidate both tokens immediately', async (t) => {
  const { app, db, login } = await fixture(t);
  const tokens = (await login()).json().data;
  await db.execute("UPDATE users SET password='different-hash' WHERE username='petani'");
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(tokens.access_token) })).statusCode, 401);
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: tokens.refresh_token } })).statusCode, 401);
});

test('readiness rejects a database that only has the original migration', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  await migrate(db, (await loadMigrations()).slice(0, 1));
  const app = buildApp({ db, config: readConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent' }) });
  t.after(() => app.close());
  assert.equal((await app.inject('/health/live')).statusCode, 200);
  assert.equal((await app.inject('/health/ready')).statusCode, 503);
});
