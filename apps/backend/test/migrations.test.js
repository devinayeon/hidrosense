import assert from 'node:assert/strict';
import { readFile, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { openDatabase, backupDatabase } from '../src/db/client.js';
import { loadMigrations, migrate, migrationStatus } from '../src/db/migrate.js';

// Preserve the original DBML contract; later migrations have separate upgrade tests.
const migrations = (await loadMigrations()).filter((migration) => migration.id === '0001_initial_schema');
const source = await readFile(new URL('../../../docs/database/hidrosense.dbml', import.meta.url), 'utf8');
const tables = [...source.matchAll(/Table (\w+) \{([^}]+)\}/g)];
const refs = [...source.matchAll(/Ref: (\w+)\.(\w+) > (\w+)\.(\w+)/g)];

async function database(t) {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  return db;
}

test('migrates all DBML tables, columns, nullability, uniqueness, defaults and references', async (t) => {
  const db = await database(t);
  assert.equal(tables.length, 19);
  assert.equal(refs.length, 23);
  await migrate(db, migrations);
  const actualTables = await db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name <> '_schema_migrations'");
  assert.deepEqual(actualTables.rows.map((r) => r.name).sort(), tables.map((m) => m[1]).sort());
  for (const [, table, body] of tables) {
    const expected = body.trim().split('\n').map((line) => {
      const [, name, type, options = ''] = line.trim().match(/^(\w+)\s+([\w(),]+)(?:\s+\[(.*)\])?$/);
      return { name, type, options };
    });
    // Table names come only from the version-controlled DBML fixture.
    const columns = (await db.execute(`PRAGMA table_info("${table}")`)).rows;
    assert.deepEqual(columns.map((c) => c.name), expected.map((c) => c.name), table);
    for (const column of expected) {
      const actual = columns.find((c) => c.name === column.name);
      const mappedType = column.options.includes('pk') || ['int', 'boolean'].includes(column.type)
        ? 'INTEGER' : column.type.startsWith('decimal') ? column.type.toUpperCase() : 'TEXT';
      assert.equal(actual.type, mappedType, `${table}.${column.name} type`);
      assert.equal(Boolean(actual.pk), column.options.includes('pk'), `${table}.${column.name} PK`);
      if (!actual.pk) assert.equal(Boolean(actual.notnull), column.options.includes('not null'), `${table}.${column.name} nullable`);
      const defaultValue = column.options.match(/default: (.+)$/)?.[1];
      assert.equal(actual.dflt_value, defaultValue === 'true' ? '1' : defaultValue?.replaceAll('`', '') ?? null);
      if (column.options.includes('unique')) {
        const indexes = (await db.execute(`PRAGMA index_list("${table}")`)).rows;
        let found = false;
        for (const index of indexes.filter((i) => i.unique)) {
          const fields = (await db.execute(`PRAGMA index_info("${index.name}")`)).rows;
          found ||= fields.length === 1 && fields[0].name === column.name;
        }
        assert.ok(found, `${table}.${column.name} unique`);
      }
    }
    const foreignKeys = (await db.execute(`PRAGMA foreign_key_list("${table}")`)).rows;
    assert.deepEqual(
      foreignKeys.map((fk) => `${fk.from}>${fk.table}.${fk.to}`).sort(),
      refs.filter((r) => r[1] === table).map((r) => `${r[2]}>${r[3]}.${r[4]}`).sort(),
    );
    for (const fk of foreignKeys) {
      assert.equal(fk.on_delete, 'NO ACTION');
      assert.equal(fk.on_update, 'NO ACTION');
      const indexes = (await db.execute(`PRAGMA index_list("${table}")`)).rows;
      let indexed = false;
      for (const index of indexes) {
        const fields = (await db.execute(`PRAGMA index_info("${index.name}")`)).rows;
        indexed ||= fields[0]?.name === fk.from;
      }
      assert.ok(indexed, `${table}.${fk.from} indexed`);
    }
  }
  assert.deepEqual((await db.execute('PRAGMA foreign_key_check')).rows, []);
});

test('enforces FK, unique, NOT NULL, boolean and length constraints; binds input safely', async (t) => {
  const db = await database(t);
  await migrate(db, migrations);
  await assert.rejects(db.execute("INSERT INTO users (id_role,nama,username,password) VALUES (999,'A','a','test-hash')"), /FOREIGN KEY/);
  await db.execute("INSERT INTO roles (nama_role) VALUES ('petani')");
  const payload = "'; DROP TABLE users; --";
  await db.execute({ sql: 'INSERT INTO users (id_role,nama,username,password) VALUES (?,?,?,?)', args: [1, 'Petani', payload, 'test-hash'] });
  const user = (await db.execute('SELECT * FROM users')).rows[0];
  assert.equal(user.username, payload);
  assert.equal(user.status_aktif, 1);
  assert.equal(user.email, null);
  await assert.rejects(db.execute("INSERT INTO roles (nama_role) VALUES ('petani')"), /UNIQUE/);
  await assert.rejects(db.execute('INSERT INTO roles (nama_role) VALUES (NULL)'), /NOT NULL/);
  await assert.rejects(db.execute('UPDATE users SET status_aktif = 2'), /CHECK/);
  await assert.rejects(db.execute({ sql: 'UPDATE users SET username=?', args: ['a'.repeat(51)] }), /CHECK/);
  await assert.rejects(db.execute('DELETE FROM roles WHERE id_role=1'), /FOREIGN KEY/);
  const plan = await db.execute('EXPLAIN QUERY PLAN SELECT * FROM users WHERE id_role=1');
  assert.ok(plan.rows.some((r) => r.detail.includes('idx_users_id_role')));
});

test('repeat migrations preserve records and defaults across the cultivation chain', async (t) => {
  const db = await database(t);
  await migrate(db, migrations);
  await db.executeMultiple(`
    INSERT INTO roles (nama_role) VALUES ('petani');
    INSERT INTO users (id_role,nama,username,password) VALUES (1,'Petani','petani','test-hash');
    INSERT INTO jenis_inventaris (nama_jenis) VALUES ('obat');
    INSERT INTO obat (nama_obat) VALUES ('Obat uji');
    INSERT INTO inventaris (id_jenis_inventaris,id_obat,nama_barang,satuan) VALUES (1,1,'Barang uji','ml');
    INSERT INTO penyemaian (id_user,tanggal_semai,jumlah_benih) VALUES (1,'2026-09-01',100);
    INSERT INTO meja_tanam (kode_meja,jumlah_lubang) VALUES ('M01',250);
    INSERT INTO pemindahan (id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES (1,1,'2026-09-16',100);
    INSERT INTO kerusakan_tanaman (id_pemindahan,tanggal_kejadian,jumlah_tanaman,jenis_kerusakan) VALUES (1,'2026-09-17',1,'Layu');
    INSERT INTO hasil_deteksi (id_pemindahan,gambar,nama_hama,confidence) VALUES (1,'local/photo.jpg','thrips',0.9123);
    INSERT INTO rekomendasi_perawatan (id_hasil_deteksi,id_obat) VALUES (1,1);
    INSERT INTO perawatan (id_rekomendasi,id_user) VALUES (1,1);
    INSERT INTO stok (id_user,id_perawatan,jenis_stok) VALUES (1,1,'keluar');
    INSERT INTO detail_stok (id_stok,id_inventaris,jumlah) VALUES (1,1,1.25);
    INSERT INTO penanganan_cuaca (kondisi_cuaca,rekomendasi) VALUES ('Hujan','Aturan uji');
    INSERT INTO panen (id_user,tanggal_panen) VALUES (1,'2026-09-30');
    INSERT INTO detail_panen (id_panen,id_pemindahan,jumlah_tanaman,berat) VALUES (1,1,90,12.25);
    INSERT INTO penjualan (id_user,tanggal_penjualan) VALUES (1,'2026-09-30');
    INSERT INTO detail_penjualan (id_penjualan,id_panen,jumlah_kg,harga_per_kg) VALUES (1,1,10.25,20000);
  `);
  assert.deepEqual(await migrate(db, migrations), []);
  for (const [, table] of tables) assert.equal((await db.execute(`SELECT count(*) AS n FROM "${table}"`)).rows[0].n, 1);
  const detection = (await db.execute('SELECT * FROM hasil_deteksi')).rows[0];
  assert.equal(detection.confidence, 0.9123);
  assert.match(detection.tanggal_deteksi, /^\d{4}-\d{2}-\d{2} /);
  assert.equal((await db.execute('SELECT status_rekomendasi FROM rekomendasi_perawatan')).rows[0].status_rekomendasi, 'menunggu');
  assert.deepEqual((await db.execute('PRAGMA foreign_key_check')).rows, []);
  // Exercise child-before-parent rollback with every domain table populated.
  await migrate(db, migrations, { direction: 'down', allowDataLoss: true });
  await migrate(db, migrations);
  assert.equal((await db.execute('SELECT count(*) AS n FROM users')).rows[0].n, 0);
});

test('status, explicit down and reapply work; rollback requires acknowledgement', async (t) => {
  const db = await database(t);
  assert.equal((await migrationStatus(db, migrations))[0].status, 'pending');
  await migrate(db, migrations);
  assert.equal((await migrationStatus(db, migrations))[0].status, 'applied');
  await assert.rejects(migrate(db, migrations, { direction: 'down' }), /allowDataLoss/);
  await migrate(db, migrations, { direction: 'down', allowDataLoss: true });
  assert.equal((await db.execute("SELECT count(*) AS n FROM sqlite_master WHERE type='table' AND name='users'")).rows[0].n, 0);
  assert.equal((await migrationStatus(db, migrations))[0].status, 'pending');
  await migrate(db, migrations);
  assert.deepEqual(await migrate(db, migrations), []);
});

test('failed SQL rolls back schema and migration history together', async (t) => {
  const db = await database(t);
  const broken = { id: '0002_broken', up: 'CREATE TABLE transient (id INTEGER); INSERT INTO missing_table VALUES (1);', down: 'DROP TABLE transient;', checksum: 'broken-test' };
  await assert.rejects(migrate(db, [...migrations, broken]), /0002_broken/);
  assert.equal((await db.execute("SELECT count(*) AS n FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")).rows[0].n, 0);
  await migrate(db, migrations);
});

test('refuses modified or missing applied migrations and preserves existing data', async (t) => {
  const db = await database(t);
  await migrate(db, migrations);
  await db.execute("INSERT INTO roles (nama_role) VALUES ('petani')");
  await assert.rejects(migrate(db, [{ ...migrations[0], checksum: 'changed' }]), /changed|checksum/i);
  await assert.rejects(migrate(db, []), /history|missing/i);
  assert.equal((await db.execute('SELECT count(*) AS n FROM roles')).rows[0].n, 1);
});

test('does not adopt or overwrite an unmanaged existing schema', async (t) => {
  const db = await database(t);
  await db.execute('CREATE TABLE roles (legacy TEXT)');
  await db.execute("INSERT INTO roles VALUES ('preserve me')");
  await assert.rejects(migrate(db, migrations), /0001/);
  assert.equal((await db.execute('SELECT legacy FROM roles')).rows[0].legacy, 'preserve me');
});

test('loads stable checksums across CRLF and rejects incomplete migration pairs', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'hidrosense-migrations-'));
  t.after(() => rm(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }));
  await writeFile(join(dir, '0001_test.up.sql'), 'CREATE TABLE t (id INTEGER);\n');
  await assert.rejects(loadMigrations(dir), /down|pair/i);
  await writeFile(join(dir, '0001_test.down.sql'), 'DROP TABLE t;\n');
  const first = await loadMigrations(dir);
  await writeFile(join(dir, '0001_test.up.sql'), 'CREATE TABLE t (id INTEGER);\r\n');
  assert.equal((await loadMigrations(dir))[0].checksum, first[0].checksum);
});

test('local file uses WAL, persists data, and creates a restorable consistent backup', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'hidrosense-backup-'));
  t.after(() => rm(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }));
  const url = `file:${join(dir, 'database.db').replaceAll('\\', '/')}`;
  let db = await openDatabase({ url });
  try {
    await migrate(db, migrations);
    assert.equal((await db.execute('PRAGMA journal_mode')).rows[0].journal_mode, 'wal');
    await db.execute("INSERT INTO roles (nama_role) VALUES ('petani')");
    await backupDatabase(db, join(dir, 'backup.db'));
    await assert.rejects(backupDatabase(db, join(dir, 'backup.db')), /exist/i);
  } finally { db.close(); }
  db = await openDatabase({ url: `file:${join(dir, 'backup.db').replaceAll('\\', '/')}` });
  try {
    assert.equal((await db.execute('SELECT nama_role FROM roles')).rows[0].nama_role, 'petani');
    assert.equal((await migrationStatus(db, migrations))[0].status, 'applied');
    assert.equal((await db.execute('PRAGMA integrity_check')).rows[0].integrity_check, 'ok');
  } finally { db.close(); }
});
