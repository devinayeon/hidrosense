// Local main applied 0012_operation_key_lower while origin/main used 0012 for table status.
// Databases built from the old local branch must still upgrade after the renumbering to 0014.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate, migrationStatus } from '../src/db/migrate.js';

const all = await loadMigrations();
const index = "SELECT COUNT(*) AS n FROM sqlite_master WHERE type='index' AND name='idx_sync_operations_key_lower'";

async function oldLocalDatabase(t) {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  await migrate(db, all.slice(0, 11));
  await db.execute('CREATE INDEX idx_sync_operations_key_lower ON sync_operations (id_user, lower(operation_key))');
  await db.execute("INSERT INTO _schema_migrations (id, checksum) VALUES ('0012_operation_key_lower', 'lama')");
  await db.executeMultiple(`
    INSERT INTO roles(nama_role) VALUES('petani');
    INSERT INTO users(id_role,nama,username,password) VALUES(1,'Petani','petani','hash');
    INSERT INTO meja_tanam(kode_meja,jumlah_lubang,status_meja) VALUES('M1',10,'tersedia');
  `);
  return db;
}

test('a database from the old local numbering upgrades and keeps its data', async (t) => {
  const db = await oldLocalDatabase(t);
  await assert.rejects(migrationStatus(db, all), /Migration history differs/);
  const applied = await migrate(db, all);
  assert.ok(applied.includes('0012_table_occupancy_status'));
  assert.ok(applied.includes('0013_sales'));
  assert.ok(applied.includes('0014_operation_key_lower'));
  assert.ok((await migrationStatus(db, all)).every((item) => item.status === 'applied'));
  assert.equal(Number((await db.execute(index)).rows[0].n), 1);
  assert.equal((await db.execute('SELECT username FROM users')).rows[0].username, 'petani');
  assert.equal(Number((await db.execute("SELECT COUNT(*) AS n FROM _schema_migrations WHERE id='0012_operation_key_lower'")).rows[0].n), 0);
  assert.deepEqual(await migrate(db, all), []);
});

test('a database already on the new numbering is not touched by the renumbering step', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  await migrate(db, all);
  assert.deepEqual(await migrate(db, all), []);
  assert.equal(Number((await db.execute(index)).rows[0].n), 1);
});
