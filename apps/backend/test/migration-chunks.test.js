import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { chunkSql, splitStatements } from '../src/db/sql-split.js';

// Diminta pengguna 2026-11-28: `node dist/db/cli.js up` di Heroku gagal
// "Migration up failed at 0026_ai_stok_rotasi: SERVER_ERROR: Server returned HTTP status 502".
// 0026 berukuran ~413 KB dan dulu dikirim ke Turso sebagai satu request.

/** Membungkus klien supaya ukuran setiap executeMultiple di dalam transaksi tercatat. */
function measured(db) {
  const sizes = [];
  const bind = (target, key) => (typeof target[key] === 'function' ? target[key].bind(target) : target[key]);
  const client = new Proxy(db, {
    get(target, key) {
      if (key !== 'transaction') return bind(target, key);
      return async (mode) => {
        const tx = await target.transaction(mode);
        return new Proxy(tx, {
          get(t, k) {
            if (k !== 'executeMultiple') return bind(t, k);
            return async (sql) => {
              sizes.push(Buffer.byteLength(sql));
              return t.executeMultiple(sql);
            };
          },
        });
      };
    },
  });
  return { client, sizes };
}

const schema = async (db) => (await db.execute(
  "SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
)).rows.map((r) => `${r.type}|${r.name}|${r.sql}`);

test('migrasi besar dikirim per potongan: tidak ada request di atas 64 KiB', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const { client, sizes } = measured(db);
  const applied = await migrate(client, await loadMigrations());
  assert.ok(applied.includes('0026_ai_stok_rotasi'));
  const terbesar = Math.max(...sizes);
  assert.ok(terbesar <= 64 * 1024, `request terbesar ${terbesar} byte, batas 65536`);
  assert.equal(Number((await db.execute('SELECT COUNT(*) n FROM merek_obat')).rows[0].n), 2769);
  assert.equal(Number((await db.execute('SELECT COUNT(*) n FROM merek_bahan')).rows[0].n), 3427);
});

test('potongan sangat kecil tetap menghasilkan skema yang sama (trigger BEGIN...END utuh)', async (t) => {
  const biasa = await openDatabase({ url: ':memory:' });
  const kecil = await openDatabase({ url: ':memory:' });
  t.after(() => { biasa.close(); kecil.close(); });
  const all = await loadMigrations();
  await migrate(biasa, all);
  await migrate(kecil, all, { maxRequestBytes: 1 });
  assert.deepEqual(await schema(kecil), await schema(biasa));
  const triggers = (await kecil.execute("SELECT COUNT(*) n FROM sqlite_master WHERE type='trigger'")).rows[0].n;
  assert.ok(Number(triggers) > 0, 'migrasi memuat trigger, jadi pemecahan BEGIN...END ikut teruji');
});

test('pemecah SQL: titik koma di string/komentar dan CASE di dalam trigger tidak memotong', () => {
  const sql = [
    "-- komentar don't; tetap komentar",
    "INSERT INTO t VALUES ('a;b', 'it''s; ok');",
    '/* blok; komentar */ CREATE TABLE "x;y" (a);',
    'CREATE TRIGGER tr AFTER INSERT ON t BEGIN',
    "  SELECT CASE WHEN NEW.a = ';' THEN RAISE(ABORT, 'no; way') END;",
    '  UPDATE t SET a = 1;',
    'END;',
    'SELECT 1',
  ].join('\n');
  const parts = splitStatements(sql);
  assert.equal(parts.length, 4, JSON.stringify(parts));
  assert.match(parts[0], /'it''s; ok'\);$/);
  assert.match(parts[2], /^\nCREATE TRIGGER[\s\S]*\nEND;$/);
  assert.equal(parts[3].trim(), 'SELECT 1');
  assert.equal(chunkSql(sql, 1).join(''), sql, 'potongan digabung kembali sama persis dengan aslinya');
  assert.deepEqual(chunkSql(sql), [sql], 'skrip kecil dikirim apa adanya');
});

test('rollback juga dipotong dan tetap utuh', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const all = await loadMigrations();
  await migrate(db, all, { maxRequestBytes: 1 });
  const down = { direction: 'down', allowDataLoss: true, maxRequestBytes: 1 };
  assert.deepEqual(await migrate(db, all, down), ['0026_ai_stok_rotasi']);
  assert.deepEqual(await migrate(db, all, down), ['0025_obat_selada_rotasi']);
  assert.equal((await db.execute("SELECT name FROM sqlite_master WHERE name='merek_obat'")).rows.length, 0);
  assert.deepEqual(await migrate(db, all, { maxRequestBytes: 1 }), ['0025_obat_selada_rotasi', '0026_ai_stok_rotasi']);
});
