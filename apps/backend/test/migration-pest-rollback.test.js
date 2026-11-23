import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';

// Review 2026-11-23: rollback 0019 lupa membuat ulang indeks 0001, jadi skema setelah
// up -> down berbeda dari skema sebelum fitur deteksi. Skema harus kembali persis.
const snapshot = async (db) => (await db.execute(`
  SELECT type, name, tbl_name, sql FROM sqlite_master
  WHERE name NOT LIKE 'sqlite_%' AND name <> '_schema_migrations' ORDER BY type, name
`)).rows.map((r) => `${r.type} ${r.name} ${r.tbl_name} ${String(r.sql ?? '').replace(/\s+/g, ' ').trim()}`);

test('0019 dan 0020: up lalu down mengembalikan skema persis seperti sebelum fitur deteksi', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const all = await loadMigrations();
  const at = all.findIndex((m) => m.id === '0019_pest_rotation');
  assert.ok(at > 0, '0019 ada');
  const upTo0020 = all.slice(0, at + 2);
  assert.equal(upTo0020.at(-1).id, '0020_catalog_phi');

  await migrate(db, all.slice(0, at));
  const before = await snapshot(db);
  await migrate(db, upTo0020);
  await migrate(db, upTo0020, { direction: 'down', allowDataLoss: true });
  await migrate(db, upTo0020.slice(0, -1), { direction: 'down', allowDataLoss: true });
  const after = await snapshot(db);

  assert.deepEqual(after.filter((s) => !before.includes(s)), [], 'objek tersisa dari fitur deteksi');
  assert.deepEqual(before.filter((s) => !after.includes(s)), [], 'objek 0001 yang hilang setelah rollback');
  await migrate(db, upTo0020);
  assert.equal(Number((await db.execute('SELECT COUNT(*) n FROM obat_katalog')).rows[0].n) > 0, true, 'up ulang berhasil');
});
