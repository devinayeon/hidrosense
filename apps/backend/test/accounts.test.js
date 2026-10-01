import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer, password } from '../test-support/fixture.js';
import { verifyPassword } from '../src/common/passwords.ts';

test('petani creates, lists, reads and updates an employee without exposing credentials', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const created = await app.inject({ method: 'POST', url: '/api/v1/employees', headers,
    payload: { nama: ' Karyawan Baru ', username: 'baru', password, email: 'baru@example.test', no_telepon: '+62 812-345', alamat: 'Kebun' } });
  assert.equal(created.statusCode, 201, created.body);
  const employee = created.json().data;
  assert.equal(employee.nama, 'Karyawan Baru');
  assert.equal(employee.role, 'pegawai');
  assert.equal(employee.status_aktif, 1);
  assert.equal(typeof employee.id_user, 'string');
  assert.equal(created.headers.location, `/api/v1/employees/${employee.id_user}`);
  assert.doesNotMatch(created.body, /password|scrypt|token/);
  const hash = (await db.execute({ sql: 'SELECT password FROM users WHERE id_user=?', args: [employee.id_user] })).rows[0].password;
  assert.ok(await verifyPassword(password, hash));
  const detail = await app.inject({ url: created.headers.location, headers });
  assert.deepEqual(detail.json().data, employee);
  const list = await app.inject({ url: '/api/v1/employees?page=2&limit=1', headers });
  assert.equal(list.statusCode, 200, list.body);
  assert.deepEqual(list.json().meta, { page: 2, limit: 1, total: 2, total_pages: 2 });
  assert.deepEqual(list.json().data, [employee]);
  const updated = await app.inject({ method: 'PATCH', url: created.headers.location, headers,
    payload: { nama: 'Nama Baru', email: null, no_telepon: null, alamat: null } });
  assert.equal(updated.statusCode, 200, updated.body);
  assert.equal(updated.json().data.nama, 'Nama Baru');
  assert.equal(updated.json().data.email, null);
  assert.equal(updated.json().data.username, 'baru');
  assert.equal((await login('baru')).statusCode, 200);
});

test('all account endpoints reject anonymous users and pegawai', async (t) => {
  const { app, login } = await fixture(t);
  const employeeHeaders = bearer((await login('pegawai')).json().data.access_token);
  const routes = [['POST', '/employees', { nama: 'x', username: 'x', password }],
    ['GET', '/employees'], ['GET', '/employees/2'], ['PATCH', '/employees/2', { nama: 'x' }],
    ['POST', '/employees/2/deactivate'], ['GET', '/profile'], ['PATCH', '/profile', { nama: 'x' }]];
  for (const [method, path, payload] of routes) {
    for (const [headers, expected] of [[{}, 401], [employeeHeaders, 403]]) {
      const response = await app.inject({ method, url: `/api/v1${path}`, headers, payload });
      assert.equal(response.statusCode, expected, `${method} ${path}: ${response.body}`);
    }
  }
});

test('account validation rejects privilege escalation, malformed IDs and unknown query keys', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  for (const payload of [{}, { role: 'petani' }, { id_role: 1 }, { status_aktif: 1 },
    { id_user: '1' }, { password: 'short' }, { nama: ' ' }, { nama: 1 }, { email: 'invalid' },
    { username: ' trailing ' }, { no_telepon: 'abc' }, { alamat: 'a'.repeat(1001) }]) {
    const response = await app.inject({ method: 'PATCH', url: '/api/v1/employees/2', headers, payload });
    assert.equal(response.statusCode, 400, response.body);
  }
  for (const id of ['0', '-1', '01', 'abc', '1.2', '9223372036854775808', '99999999999999999999']) {
    assert.equal((await app.inject({ url: `/api/v1/employees/${id}`, headers })).statusCode, 400);
  }
  for (const query of ['page=0', 'limit=101', 'limit=1.5', 'status_aktif=true', 'sort=password', 'page=1&page=2']) {
    assert.equal((await app.inject({ url: `/api/v1/employees?${query}`, headers })).statusCode, 400);
  }
  const extra = await app.inject({ method: 'POST', url: '/api/v1/employees', headers,
    payload: { nama: 'X', username: 'x', password, role: 'petani' } });
  assert.equal(extra.statusCode, 400);
});

test('employee routes cannot read, modify or deactivate petani or nonexistent accounts', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  for (const id of ['1', '999', '9223372036854775807']) {
    for (const [method, suffix, payload] of [['GET', ''], ['PATCH', '', { nama: 'Attacker' }], ['POST', '/deactivate']]) {
      assert.equal((await app.inject({ method, url: `/api/v1/employees/${id}${suffix}`, headers, payload })).statusCode, 404);
    }
  }
  assert.equal((await db.execute('SELECT nama,status_aktif FROM users WHERE id_user=1')).rows[0].nama, 'petani');
});

test('duplicate usernames conflict globally and a failed update preserves all fields', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const created = await app.inject({ method: 'POST', url: '/api/v1/employees', headers,
    payload: { nama: 'Duplicate', username: 'petani', password } });
  assert.equal(created.statusCode, 409);
  const before = (await db.execute('SELECT * FROM users WHERE id_user=2')).rows[0];
  const updated = await app.inject({ method: 'PATCH', url: '/api/v1/employees/2', headers,
    payload: { nama: 'Changed', username: 'petani' } });
  assert.equal(updated.statusCode, 409);
  assert.equal(updated.json().error.code, 'USERNAME_TAKEN');
  assert.deepEqual((await db.execute('SELECT * FROM users WHERE id_user=2')).rows[0], before);
});

test('concurrent duplicate creation produces one employee and one conflict', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const responses = await Promise.all([1, 2].map(() => app.inject({ method: 'POST', url: '/api/v1/employees', headers,
    payload: { nama: 'Concurrent', username: 'concurrent', password } })));
  assert.deepEqual(responses.map((response) => response.statusCode).sort(), [201, 409]);
  assert.equal((await db.execute("SELECT COUNT(*) AS n FROM users WHERE username='concurrent'")).rows[0].n, 1);
});

test('employee password reset revokes every session while contact edits preserve sessions', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const tokens = [(await login('pegawai')).json().data, (await login('pegawai')).json().data];
  await app.inject({ method: 'PATCH', url: '/api/v1/employees/2', headers, payload: { nama: 'Updated' } });
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(tokens[0].access_token) })).statusCode, 200);
  const newPassword = 'Updated password 2026!';
  const reset = await app.inject({ method: 'PATCH', url: '/api/v1/employees/2', headers, payload: { password: newPassword } });
  assert.equal(reset.statusCode, 200, reset.body);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM auth_sessions WHERE id_user=2')).rows[0].n, 0);
  for (const token of tokens) {
    assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(token.access_token) })).statusCode, 401);
    assert.equal((await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: token.refresh_token } })).statusCode, 401);
  }
  assert.equal((await login('pegawai')).statusCode, 401);
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'pegawai', password: newPassword } })).statusCode, 200);
});

test('deactivation is repeatable, preserves referenced history, and revokes access and refresh', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const token = (await login('pegawai')).json().data;
  await db.execute("INSERT INTO penyemaian (id_user,tanggal_semai,jumlah_benih) VALUES (2,'2026-10-01',10)");
  const history = (await db.execute('SELECT * FROM penyemaian')).rows;
  for (let i = 0; i < 2; i++) {
    const response = await app.inject({ method: 'POST', url: '/api/v1/employees/2/deactivate', headers });
    assert.equal(response.statusCode, 204, response.body);
  }
  assert.deepEqual((await db.execute('SELECT * FROM penyemaian')).rows, history);
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(token.access_token) })).statusCode, 401);
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refresh_token: token.refresh_token } })).statusCode, 401);
  assert.equal((await login('pegawai')).statusCode, 401);
  const list = await app.inject({ url: '/api/v1/employees?status_aktif=0', headers });
  assert.equal(list.json().data[0].status_aktif, 0);
  assert.equal((await app.inject({ url: '/api/v1/employees?status_aktif=1', headers })).json().meta.total, 0);
  assert.equal((await app.inject({ url: '/api/v1/employees/2', headers })).statusCode, 200);
  assert.deepEqual((await db.execute('PRAGMA foreign_key_check')).rows, []);
});
