// T-05, decided by the owner on 2026-11-04: sessions slide on refresh, capped at 30 days from
// login. Reuse of an old refresh token is refused but does not revoke the session.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { bearer, fixture } from '../test-support/fixture.js';

const DAY = 24 * 60 * 60 * 1000;
const MINUTE = 60 * 1000;

async function setup(t) {
  const f = await fixture(t);
  const login = (await f.login()).json().data;
  const refresh = (token) => f.app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: token } });
  const session = async () => (await f.db.execute('SELECT created_at,access_expires_at,refresh_expires_at FROM auth_sessions')).rows[0];
  return { ...f, login, refresh, session };
}

test('an active user is not logged out seven days after login', async (t) => {
  const { login, refresh, advance, clock } = await setup(t);
  let token = login.refresh_token;
  for (let i = 0; i < 3; i += 1) {
    advance(6 * DAY);
    const response = await refresh(token);
    assert.equal(response.statusCode, 200, response.body);
    const data = response.json().data;
    assert.equal(data.refresh_expires_at, new Date(clock() + 7 * DAY).toISOString());
    assert.equal(data.access_expires_at, new Date(clock() + 15 * MINUTE).toISOString());
    token = data.refresh_token;
  }
});

test('an idle session still ends seven days after its last refresh', async (t) => {
  const { login, refresh, advance } = await setup(t);
  advance(6 * DAY);
  const next = (await refresh(login.refresh_token)).json().data;
  advance(7 * DAY);
  const response = await refresh(next.refresh_token);
  assert.equal(response.statusCode, 401, response.body);
  assert.equal(response.json().error.code, 'UNAUTHENTICATED');
});

test('sliding never passes the 30 day cap counted from login', async (t) => {
  const { db, login, refresh, advance, clock, session } = await setup(t);
  const cap = clock() + 30 * DAY;
  const { created_at: createdAt } = await session();
  let token = login.refresh_token;
  for (const days of [6, 6, 6, 6]) {
    advance(days * DAY);
    const data = (await refresh(token)).json().data;
    token = data.refresh_token;
  }
  // Day 24: seven more days would reach day 31.
  assert.equal((await session()).refresh_expires_at, cap);
  assert.equal((await session()).created_at, createdAt);

  advance(6 * DAY - 5 * MINUTE);
  const last = await refresh(token);
  assert.equal(last.statusCode, 200, last.body);
  const data = last.json().data;
  assert.equal(data.refresh_expires_at, new Date(cap).toISOString());
  assert.equal(data.access_expires_at, new Date(cap).toISOString());
  assert.equal(data.expires_in, 300);

  advance(5 * MINUTE);
  assert.equal((await refresh(data.refresh_token)).statusCode, 401);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS n FROM auth_sessions')).rows[0].n), 1);
});

test('reusing an old refresh token is refused and revokes nothing', async (t) => {
  const { app, login, refresh, advance } = await setup(t);
  advance(MINUTE);
  const current = (await refresh(login.refresh_token)).json().data;
  assert.equal((await refresh(login.refresh_token)).statusCode, 401);
  const me = await app.inject({ url: '/api/v1/auth/me', headers: bearer(current.access_token) });
  assert.equal(me.statusCode, 200, me.body);
  assert.equal((await refresh(current.refresh_token)).statusCode, 200);
});

test('a refused refresh does not extend the session', async (t) => {
  const { db, login, refresh, advance, session } = await setup(t);
  const before = await session();
  advance(DAY);
  await db.execute("UPDATE users SET password='ganti' WHERE username='petani'");
  assert.equal((await refresh(login.refresh_token)).statusCode, 401);
  assert.deepEqual(await session(), before);
});

test('a deactivated account cannot slide its session', async (t) => {
  const { db, login, refresh, advance, session } = await setup(t);
  const before = await session();
  advance(DAY);
  await db.execute("UPDATE users SET status_aktif=0 WHERE username='petani'");
  assert.equal((await refresh(login.refresh_token)).statusCode, 401);
  assert.deepEqual(await session(), before);
});

async function plantExpired(db) {
  await db.execute(`INSERT INTO auth_sessions(id_session,id_user,access_token_hash,refresh_token_hash,credential_hash,created_at,access_expires_at,refresh_expires_at)
    VALUES ('basi',1,'a-basi','r-basi','c',1,2,3)`);
  await db.execute("INSERT INTO auth_rate_limits(bucket_key,hits,resets_at) VALUES ('basi',1,3)");
}
const planted = async (db) => [
  Number((await db.execute("SELECT COUNT(*) AS n FROM auth_sessions WHERE id_session='basi'")).rows[0].n),
  Number((await db.execute("SELECT COUNT(*) AS n FROM auth_rate_limits WHERE bucket_key='basi'")).rows[0].n),
];

// A function instance can be frozen between requests, so no timer may own this cleanup.
test('refresh sweeps expired auth records', async (t) => {
  const { db, login, refresh } = await setup(t);
  await plantExpired(db);
  assert.equal((await refresh(login.refresh_token)).statusCode, 200);
  assert.deepEqual(await planted(db), [0, 0]);
});

test('login sweeps expired auth records too', async (t) => {
  const f = await fixture(t);
  await plantExpired(f.db);
  assert.equal((await f.login()).statusCode, 200);
  assert.deepEqual(await planted(f.db), [0, 0]);
});

test('a failed sweep never fails login or refresh', async (t) => {
  const { db, login, refresh, app } = await setup(t);
  db.batch = async () => { throw new Error('database unavailable'); };
  const refreshed = await refresh(login.refresh_token);
  assert.equal(refreshed.statusCode, 200, refreshed.body);
  const signIn = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'pegawai', password: 'Fixture password 2026!' } });
  assert.equal(signIn.statusCode, 200, signIn.body);
});
