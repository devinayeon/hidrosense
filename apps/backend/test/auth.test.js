import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer, password } from '../test-support/fixture.js';

test('login creates hashed server sessions and returns safe identity', async (t) => {
  const { app, db, login } = await fixture(t);
  const response = await login();
  assert.equal(response.statusCode, 200);
  const data = response.json().data;
  assert.equal(data.token_type, 'Bearer');
  assert.equal(data.expires_in, 900);
  assert.equal(data.user.role, 'petani');
  assert.equal(typeof data.user.id_user, 'string');
  assert.match(data.access_token, /^[A-Za-z0-9_-]{43}$/);
  const session = (await db.execute('SELECT * FROM auth_sessions')).rows[0];
  assert.notEqual(session.access_token_hash, data.access_token);
  assert.notEqual(session.refresh_token_hash, data.refresh_token);
  const me = await app.inject({ url: '/api/v1/auth/me', headers: bearer(data.access_token) });
  assert.equal(me.statusCode, 200);
  assert.equal(me.json().data.username, 'petani');
  assert.doesNotMatch(me.body, /password|token_hash/);
});

test('wrong, missing, inactive and injection credentials receive the same 401', async (t) => {
  const { app, db } = await fixture(t);
  await db.execute("UPDATE users SET status_aktif=0 WHERE username='pegawai'");
  for (const [username, supplied] of [['petani', 'wrong'], ['absent', password], ['pegawai', password], ["' OR 1=1 --", password]]) {
    const response = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username, password: supplied } });
    assert.equal(response.statusCode, 401);
    assert.equal(response.json().error.code, 'INVALID_CREDENTIALS');
  }
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM auth_sessions')).rows[0].n, 0);
});

test('expired access can refresh once; rotation invalidates the old tokens', async (t) => {
  const { app, login, advance } = await fixture(t);
  const old = (await login()).json().data;
  advance(900000);
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(old.access_token) })).statusCode, 401);
  const refreshed = await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: old.refresh_token } });
  assert.equal(refreshed.statusCode, 200);
  const current = refreshed.json().data;
  assert.notEqual(current.access_token, old.access_token);
  assert.notEqual(current.refresh_token, old.refresh_token);
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(current.access_token) })).statusCode, 200);
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: old.refresh_token } })).statusCode, 401);
  advance(7 * 86400000);
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: current.refresh_token } })).statusCode, 401);
});

test('logout revokes access and refresh; unknown tokens are denied', async (t) => {
  const { app, login } = await fixture(t);
  const data = (await login()).json().data;
  const result = await app.inject({ method: 'POST', url: '/api/v1/auth/logout', headers: bearer(data.access_token) });
  assert.equal(result.statusCode, 204);
  assert.equal(result.body, '');
  for (const token of [data.access_token, 'a'.repeat(43), 'invalid']) {
    assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(token) })).statusCode, 401);
  }
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: data.refresh_token } })).statusCode, 401);
});

test('authorization rereads active status and role; refresh cannot revive disabled accounts', async (t) => {
  const { app, db, login } = await fixture(t);
  const data = (await login()).json().data;
  await db.execute("UPDATE users SET id_role=(SELECT id_role FROM roles WHERE nama_role='pegawai') WHERE username='petani'");
  const me = await app.inject({ url: '/api/v1/auth/me', headers: bearer(data.access_token) });
  assert.equal(me.json().data.role, 'pegawai');
  assert.ok(me.json().data.permissions.includes('panen:write'));
  assert.ok(!me.json().data.permissions.includes('penjualan:read'));
  await db.execute("UPDATE users SET status_aktif=0 WHERE username='petani'");
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(data.access_token) })).statusCode, 401);
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: data.refresh_token } })).statusCode, 401);
});

test('simultaneous refresh requests cannot both rotate one refresh token', async (t) => {
  const { app, login } = await fixture(t);
  const data = (await login()).json().data;
  const responses = await Promise.all([1, 2].map(() => app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: data.refresh_token } })));
  assert.deepEqual(responses.map((r) => r.statusCode).sort(), [200, 401]);
});

test('login with a stale username cannot create a session after an account rename', async (t) => {
  const { app, db, login } = await fixture(t);
  const ownerHeaders = bearer((await login()).json().data.access_token);
  const execute = db.execute.bind(db);
  let release;
  let selected;
  const continueLogin = new Promise((resolve) => { release = resolve; });
  const credentialsRead = new Promise((resolve) => { selected = resolve; });
  db.execute = async (statement) => {
    const result = await execute(statement);
    if (typeof statement === 'object' && statement.sql.includes('FROM users WHERE username=?') &&
      statement.args[0] === 'pegawai') {
      selected();
      await continueLogin;
    }
    return result;
  };
  try {
    const pendingLogin = login('pegawai');
    await credentialsRead;
    const renamed = await app.inject({ method: 'PATCH', url: '/api/v1/employees/2', headers: ownerHeaders,
      payload: { username: 'pegawai-baru' } });
    assert.equal(renamed.statusCode, 200, renamed.body);
    release();
    const response = await pendingLogin;
    assert.equal(response.statusCode, 401, response.body);
    assert.equal((await db.execute('SELECT COUNT(*) AS n FROM auth_sessions WHERE id_user=2')).rows[0].n, 0);
  } finally { db.execute = execute; }
});

test('authentication accepts a created account whose ID exceeds JavaScript safe integers', async (t) => {
  const { app, db, login } = await fixture(t);
  await db.execute({ sql: "UPDATE sqlite_sequence SET seq=? WHERE name='users'", args: ['9007199254740991'] });
  const ownerHeaders = bearer((await login()).json().data.access_token);
  const created = await app.inject({ method: 'POST', url: '/api/v1/employees', headers: ownerHeaders,
    payload: { nama: 'ID Besar', username: 'id-besar', password } });
  assert.equal(created.statusCode, 201, created.body);
  assert.equal(created.json().data.id_user, '9007199254740992');
  const loggedIn = await login('id-besar');
  assert.equal(loggedIn.statusCode, 200, loggedIn.body);
  assert.equal(loggedIn.json().data.user.id_user, '9007199254740992');
  const me = await app.inject({ url: '/api/v1/auth/me', headers: bearer(loggedIn.json().data.access_token) });
  assert.equal(me.statusCode, 200, me.body);
  assert.equal(me.json().data.id_user, '9007199254740992');
});
