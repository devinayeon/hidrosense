import assert from 'node:assert/strict';
import { test } from 'node:test';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { refreshDatabase } from '../src/db/refresh.js';
import { seed } from '../src/db/seed.js';

const backendRoot = fileURLToPath(new URL('..', import.meta.url));

const count = async (db, table) =>
  Number((await db.execute(`SELECT COUNT(*) AS n FROM ${table}`)).rows[0].n);

test('refresh drops stale tables/data, reapplies every migration and seeds clean data', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const migrations = await loadMigrations();
  await migrate(db, migrations);
  await seed(db);

  // Simulate a database that ran for a while: old rules, extra accounts, and a
  // migration row missing while the column it added is still present.
  await db.executeMultiple(`
    INSERT INTO meja_tanam (kode_meja, jumlah_lubang) VALUES ('OLD-999', 999);
    INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian)
      VALUES (2, '2026-09-01', 9999, 'aktif');
    DELETE FROM _schema_migrations WHERE id = '0024_inventaris_katalog';
  `);

  const { dropped, applied } = await refreshDatabase(db, migrations);
  assert.ok(dropped.includes('_schema_migrations'), 'migration history must be dropped too');
  assert.ok(dropped.includes('meja_tanam'));
  assert.deepEqual(applied, migrations.map((migration) => migration.id));
  assert.equal(await count(db, 'users'), 0, 'old accounts must be gone after reset');
  assert.equal(await count(db, 'penyemaian'), 0, 'old sowings must be gone after reset');

  await seed(db);
  assert.equal(await count(db, 'users'), 2);
  assert.equal(await count(db, 'meja_tanam'), 4);
  assert.equal((await db.execute("SELECT COUNT(*) AS n FROM meja_tanam WHERE kode_meja = 'OLD-999'")).rows[0].n, 0);
  assert.equal(await count(db, 'penyemaian'), 2);
  assert.equal(Number((await db.execute('SELECT MAX(jumlah_benih) AS n FROM penyemaian')).rows[0].n), 250);
  const inventaris = (await db.execute("PRAGMA table_info('inventaris')")).rows.map((row) => String(row.name));
  assert.ok(inventaris.includes('id_katalog'), 'migration 0024 must be applied');
});

test('refresh CLI refuses to run without --allow-data-loss', () => {
  const result = spawnSync(process.execPath, ['--import', 'tsx', 'src/db/refresh-cli.ts'], {
    cwd: backendRoot, env: { ...process.env }, encoding: 'utf8', timeout: 60000,
  });
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /--allow-data-loss/);
  assert.equal(result.stdout.includes('berhasil diseed ulang'), false);
});

test('refresh CLI refuses a remote database without ALLOW_PROD_SEED', () => {
  const env = { ...process.env, DATABASE_URL: 'libsql://contoh.invalid', NODE_ENV: 'development' };
  delete env.ALLOW_PROD_SEED;
  const result = spawnSync(process.execPath, ['--import', 'tsx', 'src/db/refresh-cli.ts', '--allow-data-loss'], {
    cwd: backendRoot, env, encoding: 'utf8', timeout: 60000,
  });
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /dicegah/);
  assert.equal(result.stdout.includes('berhasil diseed ulang'), false);
});