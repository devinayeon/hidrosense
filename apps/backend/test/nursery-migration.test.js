import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';

test('nursery migration 0007 applies indexes and triggers, rolls down safely, and preserves data', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());

  const migrations = (await loadMigrations()).slice(0, 7);
  // Migrate up to 0006
  await migrate(db, migrations.slice(0, 6));

  // Seed user and legacy nursery row
  await db.executeMultiple(`
    INSERT INTO roles (nama_role) VALUES ('pegawai');
    INSERT INTO users (id_role, nama, username, password) VALUES (1, 'User 1', 'user1', 'pw');
    INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian, keterangan)
      VALUES (1, '2026-10-01', 50, 'aktif', 'Legacy semai');
  `);

  const beforeRows = (await db.execute('SELECT * FROM penyemaian')).rows;
  assert.equal(beforeRows.length, 1);

  // Apply migration 0007
  await migrate(db, migrations);

  // Verify existing data preserved
  const afterRows = (await db.execute('SELECT * FROM penyemaian')).rows;
  assert.deepEqual(afterRows, beforeRows);

  // Verify trigger enforces valid status
  await assert.rejects(
    () => db.execute("INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian) VALUES (1, '2026-10-02', 10, 'invalid')"),
    /status_penyemaian harus aktif atau selesai/,
  );

  // Verify valid insert works
  await db.execute("INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian) VALUES (1, '2026-10-02', 10, 'selesai')");

  // Rollback migration 0007 down
  await migrate(db, migrations, { direction: 'down', allowDataLoss: true });

  // Verify triggers and indexes removed
  const triggers = (await db.execute("SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'trg_penyemaian%'")).rows;
  assert.equal(triggers.length, 0);

  const indexes = (await db.execute("SELECT name FROM sqlite_master WHERE type='index' AND name='idx_penyemaian_user_date'")).rows;
  assert.equal(indexes.length, 0);

  // Verify data is still intact
  const rolledBackRows = (await db.execute('SELECT * FROM penyemaian')).rows;
  assert.equal(rolledBackRows.length, 2);

  // Re-apply migration 0007
  await migrate(db, migrations);
  const finalTriggers = (await db.execute("SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'trg_penyemaian%'")).rows;
  assert.equal(finalTriggers.length, 2);
});

test('nursery list index migration 0008 supports cross-user date order and rolls back without data loss', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const migrations = (await loadMigrations()).slice(0, 8);
  await migrate(db, migrations.slice(0, 7));
  await db.executeMultiple(`INSERT INTO roles(nama_role) VALUES('pegawai');
    INSERT INTO users(id_role,nama,username,password) VALUES(1,'U','u','pw');
    INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih,status_penyemaian) VALUES(1,'2026-09-16',20,'aktif');`);
  await migrate(db, migrations);
  await migrate(db, migrations, { direction: 'down', allowDataLoss: true });
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM penyemaian')).rows[0].n, 1);
  assert.equal((await db.execute("SELECT COUNT(*) AS n FROM sqlite_master WHERE type='index' AND name='idx_penyemaian_user_date'")).rows[0].n, 1);
  await migrate(db, migrations);
  assert.equal((await db.execute('SELECT COUNT(*) AS n FROM penyemaian')).rows[0].n, 1);
  const plan = (await db.execute({ sql: `EXPLAIN QUERY PLAN SELECT id_penyemaian FROM penyemaian p
    WHERE (? IS NULL OR p.status_penyemaian=?)
    AND (? IS NULL OR julianday(p.tanggal_semai) <= julianday(?) - 15)
    ORDER BY p.tanggal_semai DESC, p.id_penyemaian DESC LIMIT ? OFFSET ?`,
    args: [null, null, null, '2026-09-30', 20, 0] })).rows.map((r) => String(r.detail)).join(' ');
  assert.match(plan, /idx_penyemaian_date/);
  assert.doesNotMatch(plan, /TEMP B-TREE FOR ORDER BY/);
});
