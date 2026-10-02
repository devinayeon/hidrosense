import assert from 'node:assert/strict';
import { test } from 'node:test';
import { bootstrapPetani } from '../src/features/auth/bootstrap.ts';
import { fixture, password } from '../test-support/fixture.js';

test('bootstrap reports existing farmer correctly even with a signed64 ID', async (t) => {
  const { db } = await fixture(t);
  await db.execute("UPDATE users SET id_user=9007199254740992 WHERE username='petani'");
  await assert.rejects(bootstrapPetani(db, { username: 'new', nama: 'New', password }),
    { statusCode: 409, code: 'ALREADY_BOOTSTRAPPED' });
  const row = (await db.execute("SELECT CAST(id_user AS TEXT) AS id,username FROM users WHERE username='petani'")).rows[0];
  assert.equal(row.id, '9007199254740992');
  assert.equal(row.username, 'petani');
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM users')).rows[0].n, 2);
});

test('bootstrap reports username conflict against a signed64 employee without mutation', async (t) => {
  const { db } = await fixture(t);
  await db.execute("DELETE FROM users WHERE username='petani'");
  await db.execute("UPDATE users SET id_user=9007199254740992 WHERE username='pegawai'");
  await assert.rejects(bootstrapPetani(db, { username: 'pegawai', nama: 'New', password }),
    { statusCode: 409, code: 'USERNAME_EXISTS' });
  const rows = (await db.execute('SELECT CAST(id_user AS TEXT) AS id,username FROM users')).rows;
  assert.equal(rows.length, 1);
  assert.equal(rows[0].id, '9007199254740992');
  assert.equal(rows[0].username, 'pegawai');
});
