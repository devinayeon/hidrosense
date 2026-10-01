import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer, password } from '../test-support/fixture.js';
import { authenticatedWrite as accountWrite } from '../src/common/authenticated-write.ts';

test('deactivation rolls back status if session deletion fails', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const tokens = (await login('pegawai')).json().data;
  await db.execute(`CREATE TRIGGER fail_revoke BEFORE DELETE ON auth_sessions
    WHEN OLD.id_user=2 BEGIN SELECT RAISE(ABORT, 'forced-secret-failure'); END`);
  const response = await app.inject({ method: 'POST', url: '/api/v1/employees/2/deactivate', headers });
  assert.equal(response.statusCode, 500);
  assert.doesNotMatch(response.body, /forced|secret|SQL|trigger/);
  assert.equal((await db.execute('SELECT status_aktif FROM users WHERE id_user=2')).rows[0].status_aktif, 1);
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(tokens.access_token) })).statusCode, 200);
});

test('credential update rolls back password and name if session deletion fails', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  await login('pegawai');
  const before = (await db.execute('SELECT * FROM users WHERE id_user=2')).rows[0];
  await db.execute(`CREATE TRIGGER fail_revoke BEFORE DELETE ON auth_sessions
    WHEN OLD.id_user=2 BEGIN SELECT RAISE(ABORT, 'forced-failure'); END`);
  const response = await app.inject({ method: 'PATCH', url: '/api/v1/employees/2', headers,
    payload: { nama: 'Changed', password: 'Replacement password 2026!' } });
  assert.equal(response.statusCode, 500);
  assert.deepEqual((await db.execute('SELECT * FROM users WHERE id_user=2')).rows[0], before);
  assert.equal((await login('pegawai')).statusCode, 200);
});

test('write boundary rejects revoked, downgraded and expired actors before mutation', async (t) => {
  const { db, login, clock, advance } = await fixture(t);
  const first = (await login()).json().data;
  await db.execute('DELETE FROM auth_sessions WHERE id_user=1');
  let mutated = false;
  const operation = async () => { mutated = true; };
  await assert.rejects(accountWrite(db, `Bearer ${first.access_token}`, 'pegawai:manage', clock, operation),
    (error) => error.statusCode === 401);
  const second = (await login()).json().data;
  await db.execute('UPDATE users SET id_role=2 WHERE id_user=1');
  await assert.rejects(accountWrite(db, `Bearer ${second.access_token}`, 'pegawai:manage', clock, operation),
    (error) => error.statusCode === 403);
  await db.execute('UPDATE users SET id_role=1 WHERE id_user=1');
  advance(15 * 60 * 1000);
  await assert.rejects(accountWrite(db, `Bearer ${second.access_token}`, 'pegawai:manage', clock, operation),
    (error) => error.statusCode === 401);
  assert.equal(mutated, false);
});

test('refresh racing deactivation never leaves a usable employee session', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const tokens = (await login('pegawai')).json().data;
  const [deactivated, refreshed] = await Promise.all([
    app.inject({ method: 'POST', url: '/api/v1/employees/2/deactivate', headers }),
    app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: tokens.refresh_token } }),
  ]);
  assert.equal(deactivated.statusCode, 204, deactivated.body);
  assert.ok([200, 401].includes(refreshed.statusCode), refreshed.body);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM auth_sessions WHERE id_user=2')).rows[0].n, 0);
  if (refreshed.statusCode === 200) {
    assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(refreshed.json().data.access_token) })).statusCode, 401);
  }
  assert.equal((await login('pegawai')).statusCode, 401);
});

test('SQL-like input remains data and cannot change another account', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const username = "x' OR 1=1 --";
  const response = await app.inject({ method: 'POST', url: '/api/v1/employees', headers,
    payload: { nama: 'SQL literal', username, password } });
  assert.equal(response.statusCode, 201, response.body);
  assert.equal(response.json().data.username, username);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM users')).rows[0].n, 3);
  assert.equal((await login(username)).statusCode, 200);
});
