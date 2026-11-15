import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer, password } from '../test-support/fixture.js';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';

const U = '/api/v1/employees';
const setup = async (t) => {
  const f = await fixture(t);
  const headers = bearer((await f.login()).json().data.access_token);
  const post = (payload) => f.app.inject({ method: 'POST', url: U, headers, payload: { nama: 'Orang', password, ...payload } });
  const patch = (id, payload) => f.app.inject({ method: 'PATCH', url: `${U}/${id}`, headers, payload });
  const loginAs = (username, pass = password) => f.app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username, password: pass } });
  return { ...f, headers, post, patch, loginAs };
};

test('a deactivated account that proves its password is told so; every other failure stays a plain 401', async (t) => {
  const { app, db, headers, loginAs } = await setup(t);
  await app.inject({ method: 'POST', url: `${U}/2/deactivate`, headers });
  const right = await loginAs('pegawai');
  assert.equal(right.statusCode, 403, right.body);
  assert.equal(right.json().error.code, 'ACCOUNT_DEACTIVATED');
  for (const [username, supplied] of [['pegawai', 'salah salah salah'], ['absent', password]]) {
    const response = await loginAs(username, supplied);
    assert.equal(response.statusCode, 401, `${username}: ${response.body}`);
    assert.equal(response.json().error.code, 'INVALID_CREDENTIALS');
  }
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM auth_sessions WHERE id_user=2')).rows[0].n, 0);
  await app.inject({ method: 'POST', url: `${U}/2/activate`, headers });
  assert.equal((await loginAs('pegawai')).statusCode, 200);
});

test('email is unique, case-insensitively, across create, update and profile', async (t) => {
  const { app, headers, post, patch } = await setup(t);
  const first = await post({ username: 'a1', email: 'Budi@Example.test' });
  assert.equal(first.statusCode, 201, first.body);
  assert.equal(first.json().data.email, 'budi@example.test');
  for (const email of ['budi@example.test', 'BUDI@EXAMPLE.TEST', '  budi@example.test  ']) {
    const dup = await post({ username: `b${email.length}`, email });
    assert.equal(dup.statusCode, 409, `${email}: ${dup.body}`);
    assert.equal(dup.json().error.code, 'EMAIL_TAKEN');
  }
  const other = await post({ username: 'a2', email: 'lain@example.test' });
  const id = other.json().data.id_user;
  const clash = await patch(id, { email: 'BUDI@example.test' });
  assert.equal(clash.statusCode, 409, clash.body);
  assert.equal(clash.json().error.code, 'EMAIL_TAKEN');
  assert.equal((await patch(id, { email: 'LAIN@example.test', nama: 'Sama' })).statusCode, 200);
  const profile = await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers, payload: { email: 'budi@example.test' } });
  assert.equal(profile.statusCode, 409, profile.body);
  assert.equal(profile.json().error.code, 'EMAIL_TAKEN');
  assert.equal((await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers, payload: { email: 'pemilik@example.test' } })).statusCode, 200);
});

test('a deactivated account keeps its email reserved, and accounts without email never collide', async (t) => {
  const { headers, app, post } = await setup(t);
  await post({ username: 'k1', email: 'k@example.test' });
  await app.inject({ method: 'POST', url: `${U}/3/deactivate`, headers });
  assert.equal((await post({ username: 'k2', email: 'k@example.test' })).statusCode, 409);
  for (const username of ['n1', 'n2', 'n3']) assert.equal((await post({ username })).statusCode, 201);
});

test('migration 0018 enforces unique email in the database, ignoring case and allowing NULL', async (t) => {
  const all = await loadMigrations();
  const index = all.findIndex((migration) => migration.id.startsWith('0018_'));
  assert.ok(index > 0, 'migration 0018 must exist');
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  await migrate(db, all.slice(0, index));
  await db.execute("INSERT INTO roles (nama_role) VALUES ('petani')");
  await db.execute("INSERT INTO users (id_role,nama,username,password,email) VALUES (1,'a','a','x','Dup@x.test')");
  await db.execute("INSERT INTO users (id_role,nama,username,password,email) VALUES (1,'b','b','x',NULL)");
  await migrate(db, all.slice(0, index + 1));
  assert.equal((await db.execute("SELECT email FROM users WHERE username='a'")).rows[0].email, 'dup@x.test');
  await db.execute("INSERT INTO users (id_role,nama,username,password) VALUES (1,'c','c','x')");
  await assert.rejects(db.execute("INSERT INTO users (id_role,nama,username,password,email) VALUES (1,'d','d','x','DUP@X.TEST')"), /UNIQUE/);
  await migrate(db, all.slice(0, index + 1), { direction: 'down', allowDataLoss: true });
  await db.execute("INSERT INTO users (id_role,nama,username,password,email) VALUES (1,'e','e','x','dup@x.test')");

  const clash = await openDatabase({ url: ':memory:' });
  t.after(() => clash.close());
  await migrate(clash, all.slice(0, index));
  await clash.execute("INSERT INTO roles (nama_role) VALUES ('petani')");
  for (const [name, email] of [['a', 'x@x.test'], ['b', 'X@x.test']]) {
    await clash.execute({ sql: "INSERT INTO users (id_role,nama,username,password,email) VALUES (1,?,?,'x',?)", args: [name, name, email] });
  }
  await assert.rejects(migrate(clash, all.slice(0, index + 1)), /0018/);
});

test('blank optional contact fields clear the value instead of failing', async (t) => {
  const { app, headers, post, patch } = await setup(t);
  const created = await post({ username: 'blk', email: '', no_telepon: '', alamat: '' });
  assert.equal(created.statusCode, 201, created.body);
  assert.deepEqual([created.json().data.email, created.json().data.no_telepon, created.json().data.alamat], [null, null, null]);
  await patch(2, { email: 'p@example.test', no_telepon: '0812', alamat: 'Kebun' });
  const cleared = await patch(2, { email: '', no_telepon: '   ', alamat: '' });
  assert.equal(cleared.statusCode, 200, cleared.body);
  assert.deepEqual([cleared.json().data.email, cleared.json().data.no_telepon, cleared.json().data.alamat], [null, null, null]);
  await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers, payload: { email: 'o@example.test', alamat: 'A' } });
  const profile = await app.inject({ method: 'PATCH', url: '/api/v1/profile', headers, payload: { email: '', alamat: '' } });
  assert.equal(profile.statusCode, 200, profile.body);
  assert.deepEqual([profile.json().data.email, profile.json().data.alamat], [null, null]);
  assert.equal((await patch(2, { nama: '' })).statusCode, 400);
});

test('nama and alamat refuse invisible, control and direction characters; alamat may span lines', async (t) => {
  const { post, patch } = await setup(t);
  let i = 0;
  for (const nama of ['​', 'A‮B', 'Budi\nSantoso', 'Bu\u0000di', 'ㅤ', 'A B', 'A\tB']) {
    const response = await post({ username: `h${i++}`, nama });
    assert.equal(response.statusCode, 400, `nama ${JSON.stringify(nama)}: ${response.body}`);
    assert.equal((await patch(2, { nama })).statusCode, 400, `patch ${JSON.stringify(nama)}`);
  }
  for (const alamat of ['​', 'A‮B', 'Bu\u0000di', 'ㅤ']) {
    assert.equal((await post({ username: `h${i++}`, alamat })).statusCode, 400, `alamat ${JSON.stringify(alamat)}`);
  }
  assert.equal((await post({ username: 'ok1', nama: 'Siti Nurhaliza', alamat: 'Jl. Mawar 1\nRT 2, RW 3' })).statusCode, 201);
  assert.equal((await post({ username: 'ok2', nama: "D'Arc-O’Neil Éka" })).statusCode, 201);
});

test('usernames made of invisible blank letters are refused too', async (t) => {
  const { post } = await setup(t);
  for (const username of ['ㅤ', 'aㅤb', 'aᅟb', 'a⠀b', 'a͏b']) {
    assert.equal((await post({ username })).statusCode, 400, JSON.stringify(username));
  }
});

test('search ignores case for non-ASCII letters and treats composed and decomposed text alike', async (t) => {
  const { app, headers, post } = await setup(t);
  await post({ username: 'ekap', nama: 'Éka Putri' });
  await post({ username: 'caféx', nama: 'Kafe' });
  const result = async (q, extra = '') => (await app.inject({ url: `${U}?q=${encodeURIComponent(q)}${extra}`, headers })).json();
  assert.equal((await result('éka')).meta.total, 1);
  assert.equal((await result('ÉKA')).meta.total, 1);
  assert.equal((await result('café')).meta.total, 1);
  assert.equal((await result('KAP')).meta.total, 1);
  assert.equal((await result('zzz')).meta.total, 0);
  assert.equal((await result('a', '&limit=1&page=2')).data.length, 1);
  assert.deepEqual((await result('a', '&limit=1&page=2')).meta, { page: 2, limit: 1, total: 3, total_pages: 3 });
});
