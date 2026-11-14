import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer, password } from '../test-support/fixture.js';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';

const create = (app, headers, payload) => app.inject({ method: 'POST', url: '/api/v1/employees', headers, payload: { nama: 'Orang', password, ...payload } });
const loginAs = (app, username, pass = password) => app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username, password: pass } });

test('usernames are stored in one canonical form: NFC and lowercase', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const first = await create(app, headers, { username: 'Budi.Santoso' });
  assert.equal(first.statusCode, 201, first.body);
  assert.equal(first.json().data.username, 'budi.santoso');
  const second = await create(app, headers, { username: 'BUDI.SANTOSO' });
  assert.equal(second.statusCode, 409, second.body);
  assert.equal(second.json().error.code, 'USERNAME_TAKEN');
  for (const spelling of ['budi.santoso', 'Budi.Santoso', 'BUDI.SANTOSO']) {
    assert.equal((await loginAs(app, spelling)).statusCode, 200, spelling);
  }
});

test('composed and decomposed Unicode spellings are the same username', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  assert.equal((await create(app, headers, { username: 'café' })).statusCode, 201);
  const decomposed = await create(app, headers, { username: 'café' });
  assert.equal(decomposed.statusCode, 409, decomposed.body);
  assert.equal((await loginAs(app, 'café')).statusCode, 200);
  assert.equal((await loginAs(app, 'CAFÉ')).statusCode, 200);
});

test('usernames with invisible, control or odd whitespace characters are refused', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  for (const username of ['a​b', 'a‮b', 'a\u0000b', 'a\tb', 'a\nb', 'a b', 'a b', 'a  b', '﻿ab']) {
    const response = await create(app, headers, { username });
    assert.equal(response.statusCode, 400, `${JSON.stringify(username)}: ${response.body}`);
  }
  assert.equal((await create(app, headers, { username: 'dua kata' })).statusCode, 201);
});

test('username limit counts the canonical form, not the spelling sent', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  assert.equal((await create(app, headers, { username: 'a'.repeat(50) })).statusCode, 201);
  assert.equal((await create(app, headers, { username: 'b'.repeat(51) })).statusCode, 400);
});

test('changing only the casing of an own username changes nothing and keeps sessions', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const token = (await login('pegawai')).json().data;
  const response = await app.inject({ method: 'PATCH', url: '/api/v1/employees/2', headers, payload: { username: 'PEGAWAI' } });
  assert.equal(response.statusCode, 200, response.body);
  assert.equal(response.json().data.username, 'pegawai');
  assert.equal((await app.inject({ url: '/api/v1/auth/me', headers: bearer(token.access_token) })).statusCode, 200);
  assert.equal((await db.execute('SELECT username FROM users WHERE id_user=2')).rows[0].username, 'pegawai');
});

test('renaming onto a casing variant of another username conflicts', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const response = await app.inject({ method: 'PATCH', url: '/api/v1/employees/2', headers, payload: { username: 'PETANI' } });
  assert.equal(response.statusCode, 409, response.body);
  assert.equal(response.json().error.code, 'USERNAME_TAKEN');
});

test('profile rename is canonical too', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const response = await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers,
    payload: { username: 'Pak.Agus', current_password: password } });
  assert.equal(response.statusCode, 200, response.body);
  assert.equal(response.json().data.username, 'pak.agus');
  assert.equal((await loginAs(app, 'PAK.AGUS')).statusCode, 200);
});

test('login attempts share one rate-limit bucket across spellings of a username', async (t) => {
  const { app } = await fixture(t);
  const spellings = ['petani', 'Petani', 'PETANI', 'pEtAnI', 'petani', 'Petani', 'PETANI', 'pEtAnI', 'petani', 'Petani'];
  for (const spelling of spellings) assert.equal((await loginAs(app, spelling, 'wrong password!')).statusCode, 401);
  assert.equal((await loginAs(app, 'PeTaNi', 'wrong password!')).statusCode, 429);
});

test('bootstrap stores the canonical username', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  await migrate(db, await loadMigrations());
  const { bootstrapPetani } = await import('../src/features/auth/bootstrap.ts');
  const user = await bootstrapPetani(db, { username: 'Pak.Agus', nama: 'Petani', password });
  assert.equal(user.username, 'pak.agus');
  assert.equal((await db.execute('SELECT username FROM users')).rows[0].username, 'pak.agus');
  await assert.rejects(bootstrapPetani(db, { username: 'PAK.AGUS', nama: 'Lain', password }));
});

test('migration 0017 lowercases existing usernames, refuses collisions, and guards new writes', async (t) => {
  const all = await loadMigrations();
  const index = all.findIndex((migration) => migration.id.startsWith('0017_'));
  assert.ok(index > 0, 'migration 0017 must exist');
  const before = all.slice(0, index);
  const seed = async (db, names) => {
    await db.execute("INSERT INTO roles (nama_role) VALUES ('petani'),('pegawai')");
    for (const name of names) await db.execute({ sql: "INSERT INTO users (id_role,nama,username,password) VALUES (1,?,?,'x')", args: [name, name] });
  };

  const ok = await openDatabase({ url: ':memory:' });
  t.after(() => ok.close());
  await migrate(ok, before);
  await seed(ok, ['Petani', 'Budi.Santoso']);
  await migrate(ok, all.slice(0, index + 1));
  assert.deepEqual((await ok.execute('SELECT username FROM users ORDER BY id_user')).rows.map((row) => row.username), ['petani', 'budi.santoso']);
  await assert.rejects(ok.execute("INSERT INTO users (id_role,nama,username,password) VALUES (1,'x','Mixed','x')"), /lowercase/);
  await assert.rejects(ok.execute("UPDATE users SET username='MiXed' WHERE id_user=1"), /lowercase/);
  await ok.execute("INSERT INTO users (id_role,nama,username,password) VALUES (1,'x','fine','x')");
  await migrate(ok, all.slice(0, index + 1), { direction: 'down', allowDataLoss: true });
  await ok.execute("INSERT INTO users (id_role,nama,username,password) VALUES (1,'x','Mixed','x')");

  const clash = await openDatabase({ url: ':memory:' });
  t.after(() => clash.close());
  await migrate(clash, before);
  await seed(clash, ['budi', 'Budi']);
  await assert.rejects(migrate(clash, all.slice(0, index + 1)), /0017/);
  assert.deepEqual((await clash.execute('SELECT username FROM users ORDER BY id_user')).rows.map((row) => row.username), ['budi', 'Budi']);
});

test('q searches literally: % and _ are not wildcards', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  await create(app, headers, { username: 'abc', nama: 'Abc' });
  await create(app, headers, { username: 'a_c', nama: 'A_c' });
  await create(app, headers, { username: 'fifty', nama: '50% Off' });
  const total = async (q) => (await app.inject({ url: `/api/v1/employees?q=${encodeURIComponent(q)}`, headers })).json().meta.total;
  assert.equal(await total('%'), 1);
  assert.equal(await total('_'), 1);
  assert.equal(await total('a_c'), 1);
  assert.equal(await total('\\'), 0);
  assert.equal(await total('ab'), 1);
});

test('phone numbers need a digit and passwords need a visible character', async (t) => {
  const { app, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  for (const no_telepon of ['---', '+', '( )', '   ']) {
    assert.equal((await create(app, headers, { username: 'tel', no_telepon })).statusCode, 400, no_telepon);
  }
  assert.equal((await create(app, headers, { username: 'tel', no_telepon: '+62 812-345' })).statusCode, 201);
  for (const bad of [' '.repeat(12), '\t'.repeat(12), ' '.repeat(40)]) {
    assert.equal((await create(app, headers, { username: 'sp', password: bad })).statusCode, 400);
    assert.equal((await app.inject({ method: 'PATCH', url: '/api/v1/employees/2', headers, payload: { password: bad } })).statusCode, 400);
    assert.equal((await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers, payload: { password: bad, current_password: password } })).statusCode, 400);
  }
  assert.equal((await create(app, headers, { username: 'ok', password: 'kata sandi dengan spasi' })).statusCode, 201);
});

test('deactivate and activate accept an empty or {} JSON body but still refuse real content', async (t) => {
  const { app, db, login } = await fixture(t);
  const headers = bearer((await login()).json().data.access_token);
  const json = { ...headers, 'content-type': 'application/json' };
  for (const action of ['deactivate', 'activate']) {
    const url = `/api/v1/employees/2/${action}`;
    assert.equal((await app.inject({ method: 'POST', url, headers: json, payload: '' })).statusCode, 204, `${action} empty`);
    assert.equal((await app.inject({ method: 'POST', url, headers: json, payload: '{}' })).statusCode, 204, `${action} {}`);
    assert.equal((await app.inject({ method: 'POST', url, headers })).statusCode, 204, `${action} none`);
    for (const payload of ['{"x":1}', '[]', 'null', '{', 'abc']) {
      assert.equal((await app.inject({ method: 'POST', url, headers: json, payload })).statusCode, 400, `${action} ${payload}`);
    }
  }
  assert.equal((await db.execute('SELECT status_aktif FROM users WHERE id_user=2')).rows[0].status_aktif, 1);
  const anonymous = await app.inject({ method: 'POST', url: '/api/v1/employees/2/deactivate', headers: { 'content-type': 'application/json' }, payload: '' });
  assert.equal(anonymous.statusCode, 401);
});

test('an empty JSON body is still refused on routes that need a body', async (t) => {
  const { app, login } = await fixture(t);
  const headers = { ...bearer((await login()).json().data.access_token), 'content-type': 'application/json' };
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/employees', headers, payload: '' })).statusCode, 400);
});
