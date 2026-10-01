import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer, password } from '../test-support/fixture.js';

test('petani reads and edits own profile; contacts can be cleared without ending the session', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const profile = await app.inject({ url: '/api/v1/profile', headers });
  assert.equal(profile.statusCode, 200);
  assert.equal(profile.json().data.id_user, '1');
  assert.doesNotMatch(profile.body, /password|token|scrypt/);
  const updated = await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers,
    payload: { nama: 'Pemilik', email: 'owner@example.test', no_telepon: '0812345', alamat: 'Kebun A' } });
  assert.equal(updated.statusCode, 200, updated.body);
  assert.equal(updated.json().data.nama, 'Pemilik');
  const cleared = await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers,
    payload: { email: null, no_telepon: null, alamat: null } });
  assert.equal(cleared.json().data.email, null);
  assert.equal(cleared.json().data.no_telepon, null);
  assert.equal(cleared.json().data.alamat, null);
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers })).statusCode, 200);
});

test('profile refuses identity, role, status, empty updates and missing current password', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const before = (await db.execute('SELECT * FROM users')).rows;
  for (const payload of [{}, { current_password: password }, { id_user: '2', nama: 'Other' },
    { role: 'pegawai' }, { id_role: 2 }, { status_aktif: 0 }, { username: 'new' },
    { password: 'New password 2026!' }, { email: 'bad' }]) {
    const response = await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers, payload });
    assert.equal(response.statusCode, 400, response.body);
  }
  const incorrect = await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers,
    payload: { password: 'New password 2026!', current_password: 'wrong', nama: 'Wrong' } });
  assert.equal(incorrect.statusCode, 403);
  assert.equal(incorrect.json().error.code, 'CURRENT_PASSWORD_INVALID');
  assert.deepEqual((await db.execute('SELECT * FROM users')).rows, before);
});

test('profile credential changes revoke all sessions and require the new credentials', async (t) => {
  const { app, db, login } = await fixture(t);
  const tokens = [(await login()).json().data, (await login()).json().data];
  const newPassword = 'Replacement password 2026!';
  const response = await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers: bearer(tokens[0].access_token),
    payload: { username: 'pemilik', password: newPassword, current_password: password } });
  assert.equal(response.statusCode, 200, response.body);
  assert.equal(response.json().data.username, 'pemilik');
  assert.doesNotMatch(response.body, /password|scrypt|token/);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM auth_sessions WHERE id_user=1')).rows[0].n, 0);
  for (const token of tokens) {
    assert.equal((await app.inject({ url: '/api/v1/profile', headers: bearer(token.access_token) })).statusCode, 401);
    assert.equal((await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: token.refresh_token } })).statusCode, 401);
  }
  assert.equal((await login()).statusCode, 401);
  const loggedIn = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'pemilik', password: newPassword } });
  assert.equal(loggedIn.statusCode, 200);
});

test('profile duplicate username preserves fields and the current session', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const response = await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers,
    payload: { username: 'pegawai', nama: 'Changed', current_password: password } });
  assert.equal(response.statusCode, 409);
  const profile = await app.inject({ url: '/api/v1/profile', headers });
  assert.equal(profile.statusCode, 200);
  assert.equal(profile.json().data.nama, 'petani');
});

test('username-only employee update revokes old sessions and preserves its password', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const tokens = (await login('pegawai')).json().data;
  const response = await app.inject({ method: 'PATCH', url: '/api/v1/employees/2', headers, payload: { username: 'renamed' } });
  assert.equal(response.statusCode, 200);
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(tokens.access_token) })).statusCode, 401);
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: tokens.refresh_token } })).statusCode, 401);
  assert.equal((await login('renamed')).statusCode, 200);
});
