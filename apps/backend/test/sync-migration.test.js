import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';

test('sync identity upgrade preserves legacy records and rollback preserves domain history', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  // This test brackets 0005 specifically; later schema expansions have their own upgrade tests.
  const migrations = (await loadMigrations()).slice(0, 5);
  await migrate(db, migrations.slice(0, 4));
  await db.execute("INSERT INTO jenis_inventaris (nama_jenis) VALUES ('Legacy')");
  await db.execute("INSERT INTO inventaris (id_jenis_inventaris,nama_barang,satuan) VALUES (1,'Legacy item','kg')");
  const before = (await db.execute('SELECT * FROM inventaris')).rows;
  await migrate(db, migrations);
  assert.deepEqual((await db.execute('SELECT * FROM inventaris')).rows, before);
  const links = (await db.execute('SELECT * FROM sync_resource_links')).rows;
  assert.equal(links.length, 2);
  assert.match(String(links[0].public_id), /^[a-f0-9-]{36}$/);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM sync_resource_versions WHERE version=1')).rows[0].n, 2);
  await migrate(db, migrations);
  assert.deepEqual((await db.execute('SELECT * FROM sync_resource_links')).rows, links);
  await migrate(db, migrations, { direction: 'down', allowDataLoss: true });
  assert.deepEqual((await db.execute('SELECT * FROM inventaris')).rows, before);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM sync_resource_versions')).rows[0].n, 0);
});

test('0012 builds the canonical-key index even with case-variant receipts and drops it on rollback', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const all = await loadMigrations();
  await migrate(db, all);
  await db.execute("INSERT INTO roles (nama_role) VALUES ('petani')");
  await db.execute("INSERT INTO users (id_role,nama,username,password) VALUES (1,'A','a','x')");
  const lower = 'a'.repeat(36), upper = 'a'.repeat(35) + 'B';
  await db.execute({
    sql: `INSERT INTO sync_operations (id_user,operation_key,operation_type,payload_hash,result_json,created_at)
      VALUES (1,?,?,?,?,0),(1,?,?,?,?,0)`,
    args: [lower, 'stok.create', 'b'.repeat(64), '{}', upper, 'stok.create', 'b'.repeat(64), '{}'],
  });
  const indexCount = async () => Number((await db.execute({
    sql: "SELECT COUNT(*) AS n FROM sqlite_master WHERE type='index' AND name='idx_sync_operations_key_lower'",
  })).rows[0].n);
  assert.equal(await indexCount(), 1);
  await migrate(db, all, { direction: 'down', allowDataLoss: true });
  assert.equal(await indexCount(), 0);
});
