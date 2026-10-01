import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';

test('sync identity upgrade preserves legacy records and rollback preserves domain history', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const migrations = await loadMigrations();
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
