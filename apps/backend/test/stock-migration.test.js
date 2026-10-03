import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';

const migrations = (await loadMigrations()).slice(0, 6);
async function legacy(t) {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  await migrate(db, migrations.slice(0, 5));
  await db.executeMultiple(`
    INSERT INTO roles (nama_role) VALUES ('pegawai');
    INSERT INTO users (id_role,nama,username,password) VALUES (1,'A','a','fixture');
    INSERT INTO jenis_inventaris (nama_jenis) VALUES ('Material');
    INSERT INTO inventaris (id_jenis_inventaris,nama_barang,satuan,stok_minimum)
      VALUES (1,'A','kg',0.1),(1,'B','ml',NULL);
  `);
  return db;
}
async function movement(db, direction, amount, item = 1) {
  const result = await db.execute({
    sql: "INSERT INTO stok (id_user,jenis_stok,tanggal_stok) VALUES (1,?,'2026-10-03 00:00:00')",
    args: [direction],
  });
  await db.execute({ sql: 'INSERT INTO detail_stok (id_stok,id_inventaris,jumlah) VALUES (?,?,?)',
    args: [String(result.lastInsertRowid), item, amount] });
  return String(result.lastInsertRowid);
}
async function fingerprint(db) {
  const tables = ['stok', 'detail_stok', 'inventaris', 'sync_resource_links', 'sync_resource_versions',
    'sync_id_maps', 'sync_operations', '_schema_migrations', 'sqlite_sequence'];
  return Promise.all(tables.map(async (name) => (await db.execute(`SELECT * FROM ${name} ORDER BY 1,2`)).rows));
}
async function schema(db) {
  return (await db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY type,name")).rows;
}
test('stock upgrade preserves populated columns, references, sync metadata and sequence IDs', async (t) => {
  const db = await legacy(t);
  await movement(db, 'masuk', '1.25');
  await movement(db, 'keluar', '0.1');
  await movement(db, 'keluar', '0.2');
  await movement(db, 'masuk', '9999999999.99', 2);
  await db.executeMultiple(`
    INSERT INTO sync_resource_links VALUES ('stok','1','12345678-1234-4234-8234-123456789abc');
    INSERT INTO sync_resource_versions VALUES ('stok','12345678-1234-4234-8234-123456789abc',1,1);
    INSERT INTO sync_id_maps VALUES (1,'stok','12345678-1234-4234-8234-123456789abd',
      '12345678-1234-4234-8234-123456789abc',1);
    INSERT INTO sync_operations (id_user,operation_key,operation_type,payload_hash,result_json,created_at)
      VALUES (1,'12345678-1234-4234-8234-123456789abe','stok.create',
      '${'a'.repeat(64)}','{"legacy":true}',1);
  `);
  const original = await fingerprint(db);
  await migrate(db, migrations);
  const after = await fingerprint(db);
  for (const index of [0, 1, 2]) {
    const keys = Object.keys(original[index][0]);
    assert.deepEqual(after[index].map((row) => Object.fromEntries(keys.map((key) => [key, row[key]]))), original[index]);
  }
  assert.deepEqual(after[5], original[5]);
  assert.deepEqual(after[6], original[6]);
  for (const row of original[3]) assert.ok(after[3].some((next) => next.public_id === row.public_id));
  for (const row of original[4]) assert.ok(after[4].some((next) => next.public_id === row.public_id && next.changed_at === row.changed_at));
  assert.deepEqual(after[8].filter((row) => row.name !== '_schema_migrations'), original[8]);
  assert.deepEqual((await db.execute('SELECT jumlah_minor,satuan FROM detail_stok ORDER BY id_detail_stok')).rows.map((r) => [r.jumlah_minor, r.satuan]),
    [[125, 'kg'], [10, 'kg'], [20, 'kg'], [999999999999, 'ml']]);
  assert.deepEqual((await db.execute('SELECT * FROM stok_saldo ORDER BY id_inventaris')).rows.map((r) => [r.id_inventaris, r.saldo_minor]),
    [[1, 95], [2, 999999999999]]);
  assert.deepEqual((await db.execute('SELECT stok_minimum_minor FROM inventaris ORDER BY id_inventaris')).rows.map((r) => r.stok_minimum_minor), [10, null]);
  assert.equal((await db.execute('SELECT count(*) AS n FROM stok WHERE sealed=1')).rows[0].n, 4);
  assert.equal((await db.execute("SELECT count(*) AS n FROM sync_resource_links WHERE resource_type='stok'")).rows[0].n, 4);
  assert.deepEqual((await db.execute('PRAGMA foreign_key_check')).rows, []);
  assert.equal((await db.execute('PRAGMA integrity_check')).rows[0].integrity_check, 'ok');
  const upgraded = await fingerprint(db);
  assert.deepEqual(await migrate(db, migrations), []);
  assert.deepEqual(await fingerprint(db), upgraded);
  await assert.rejects(migrate(db, migrations, { direction: 'down', allowDataLoss: true }), /b006_down_requires_empty_stock/);
  assert.deepEqual(await fingerprint(db), upgraded);
});

const invalidLegacy = [
  ['excess precision', (db) => movement(db, 'masuk', '0.001')],
  ['negative quantity', (db) => movement(db, 'masuk', '-1')],
  ['zero quantity', (db) => movement(db, 'masuk', '0')],
  ['scientific numeric text', (db) => movement(db, 'masuk', '1e30')],
  ['non-numeric text', (db) => movement(db, 'masuk', 'abc')],
  ['blob', async (db) => { await movement(db, 'masuk', '1'); await db.execute("UPDATE detail_stok SET jumlah=x'3132'"); }],
  ['over cap', (db) => movement(db, 'masuk', '10000000000')],
  ['invalid direction', (db) => movement(db, 'unknown', '1')],
  ['empty header', (db) => db.execute("INSERT INTO stok (id_user,jenis_stok) VALUES (1,'masuk')")],
  ['duplicate item', async (db) => { await movement(db, 'masuk', '1'); await db.execute('INSERT INTO detail_stok (id_stok,id_inventaris,jumlah) VALUES (1,1,1)'); }],
  ['negative prefix despite positive final', async (db) => { await movement(db, 'keluar', '1'); await movement(db, 'masuk', '2'); }],
  ['overflow prefix', async (db) => { await movement(db, 'masuk', '9999999999.99'); await movement(db, 'masuk', '0.01'); }],
  ['invalid calendar day', async (db) => { await movement(db, 'masuk', '1'); await db.execute("UPDATE stok SET tanggal_stok='2026-02-30 00:00:00'"); }],
  ['unknown timestamp', async (db) => { await movement(db, 'masuk', '1'); await db.execute("UPDATE stok SET tanggal_stok='yesterday'"); }],
  ['untrimmed unit', (db) => db.execute("UPDATE inventaris SET satuan=' kg '")],
  ['untrimmed tab unit', (db) => db.execute("UPDATE inventaris SET satuan=char(9)||'kg'")],
  ['untrimmed unicode unit', (db) => db.execute("UPDATE inventaris SET satuan='kg'||char(160)")],
  ['empty unit', (db) => db.execute("UPDATE inventaris SET satuan=''")],
  ['zero minimum', (db) => db.execute('UPDATE inventaris SET stok_minimum=0')],
  ['excess minimum precision', (db) => db.execute('UPDATE inventaris SET stok_minimum=0.001')],
  ['incoming domain link', async (db) => {
    await db.execute("INSERT INTO penyemaian (id_user,tanggal_semai,jumlah_benih) VALUES (1,'2026-10-03',1)");
    await movement(db, 'masuk', '1'); await db.execute('UPDATE stok SET id_penyemaian=1');
  }],
  ['duplicate source link', async (db) => {
    await db.execute("INSERT INTO penyemaian (id_user,tanggal_semai,jumlah_benih) VALUES (1,'2026-10-03',1)");
    await movement(db, 'masuk', '3'); await movement(db, 'keluar', '1'); await movement(db, 'keluar', '1');
    await db.execute('UPDATE stok SET id_penyemaian=1 WHERE id_stok>1');
  }],
  ['too many details', async (db) => {
    await movement(db, 'masuk', '1');
    for (let id = 2; id <= 101; id++) {
      if (id > 2) await db.execute({ sql: "INSERT INTO inventaris(id_inventaris,id_jenis_inventaris,nama_barang,satuan) VALUES (?,1,'X','kg')", args: [id] });
      await db.execute({ sql: 'INSERT INTO detail_stok(id_stok,id_inventaris,jumlah) VALUES (1,?,1)', args: [id] });
    }
  }],
];
for (const [label, seed] of invalidLegacy) {
  test(`stock preflight aborts ${label} without schema, data or migration-history changes`, async (t) => {
    const db = await legacy(t); await seed(db);
    const before = await fingerprint(db); const structure = await schema(db);
    await assert.rejects(migrate(db, migrations), /b006_legacy_preflight/);
    assert.deepEqual(await fingerprint(db), before);
    assert.deepEqual(await schema(db), structure);
  });
}

test('SQL guards preserve immutable history, exact companions, unit lock and balance bounds', async (t) => {
  const db = await legacy(t); await movement(db, 'masuk', '1'); await migrate(db, migrations);
  const rejected = [
    ['UPDATE stok SET keterangan=\'changed\' WHERE id_stok=1', /IMMUTABLE/],
    ['DELETE FROM stok WHERE id_stok=1', /IMMUTABLE/],
    ["INSERT OR REPLACE INTO stok(id_stok,id_user,jenis_stok) VALUES (1,1,'keluar')", /IMMUTABLE/],
    ['UPDATE detail_stok SET jumlah_minor=99 WHERE id_stok=1', /IMMUTABLE/],
    ['DELETE FROM detail_stok WHERE id_stok=1', /IMMUTABLE/],
    ["INSERT INTO detail_stok(id_stok,id_inventaris,jumlah,jumlah_minor,satuan) VALUES (1,2,1,100,'ml')", /SEALED/],
    ["UPDATE inventaris SET satuan='g' WHERE id_inventaris=1", /UNIT_LOCKED/],
    ["INSERT OR REPLACE INTO inventaris(id_inventaris,id_jenis_inventaris,nama_barang,satuan) VALUES (1,1,'A','g')", /UNIT_LOCKED/],
    ['UPDATE inventaris SET stok_minimum=1 WHERE id_inventaris=1', /MINIMUM_INVALID/],
    ['UPDATE inventaris SET stok_minimum_minor=NULL WHERE id_inventaris=1', /MINIMUM_INVALID/],
    ['UPDATE stok_saldo SET saldo_minor=-1', /CHECK/],
    ['UPDATE stok_saldo SET saldo_minor=1000000000000', /CHECK/],
    ['UPDATE stok_saldo SET saldo_minor=0.1', /CHECK/],
    ["INSERT INTO stok(id_user,jenis_stok,sealed) VALUES (1,'masuk',1)", /HEADER_INVALID/],
    ["INSERT INTO stok(id_user,jenis_stok) VALUES (1,'wrong')", /HEADER_INVALID/],
  ];
  for (const [sql, pattern] of rejected) await assert.rejects(db.execute(sql), pattern);
  await db.execute('UPDATE stok_saldo SET saldo_minor=0');
  await assert.rejects(db.execute("UPDATE inventaris SET satuan='g' WHERE id_inventaris=1"), /UNIT_LOCKED/);
  await db.execute('UPDATE inventaris SET stok_minimum=1.25,stok_minimum_minor=125 WHERE id_inventaris=1');
  await db.execute('UPDATE inventaris SET stok_minimum=NULL,stok_minimum_minor=NULL WHERE id_inventaris=1');
  await db.execute("INSERT INTO stok(id_user,jenis_stok) VALUES (1,'keluar')");
  await assert.rejects(db.execute('UPDATE stok SET sealed=1 WHERE id_stok=2'), /IMMUTABLE/);
  for (const [amount, minor, unit] of [['1', null, 'kg'], ['0.001', 1, 'kg'], ['1', 100, 'g'], ['1', 100.1, 'kg']]) {
    await assert.rejects(db.execute({ sql: 'INSERT INTO detail_stok(id_stok,id_inventaris,jumlah,jumlah_minor,satuan) VALUES (2,1,?,?,?)',
      args: [amount, minor, unit] }), /DETAIL_INVALID|CHECK/);
  }
  await db.execute("INSERT INTO detail_stok(id_stok,id_inventaris,jumlah,jumlah_minor,satuan) VALUES (2,1,1,100,'kg')");
  await assert.rejects(db.execute("INSERT OR REPLACE INTO detail_stok(id_stok,id_inventaris,jumlah,jumlah_minor,satuan) VALUES (2,1,0.5,50,'kg')"), /IMMUTABLE/);
  await assert.rejects(db.execute("UPDATE stok SET sealed=1,keterangan='changed' WHERE id_stok=2"), /IMMUTABLE/);
  await db.execute('UPDATE stok SET sealed=1 WHERE id_stok=2');
  await assert.rejects(db.execute('UPDATE stok SET sealed=0 WHERE id_stok=2'), /IMMUTABLE/);
});

test('legacy signed64 IDs and ISO millisecond timestamps survive without numeric coercion', async (t) => {
  const db = await legacy(t);
  const stockId = '9223372036854775806'; const detailId = '9223372036854775805';
  await db.execute({
    sql: "INSERT INTO stok(id_stok,id_user,jenis_stok,tanggal_stok) VALUES (?,1,'masuk','2026-10-03T03:12:34.123Z')",
    args: [stockId],
  });
  await db.execute({ sql: 'INSERT INTO detail_stok(id_detail_stok,id_stok,id_inventaris,jumlah) VALUES (?,?,1,0.01)',
    args: [detailId, stockId] });
  await migrate(db, migrations);
  assert.equal((await db.execute('SELECT CAST(id_stok AS TEXT) AS id,tanggal_stok FROM stok')).rows[0].id, stockId);
  assert.equal((await db.execute('SELECT CAST(id_detail_stok AS TEXT) AS id FROM detail_stok')).rows[0].id, detailId);
  assert.equal((await db.execute("SELECT domain_id FROM sync_resource_links WHERE resource_type='stok'")).rows[0].domain_id, stockId);
  assert.equal((await db.execute('SELECT saldo_minor FROM stok_saldo')).rows[0].saldo_minor, 1);
  assert.equal((await db.execute('SELECT tanggal_stok FROM stok')).rows[0].tanggal_stok, '2026-10-03T03:12:34.123Z');
});

test('future consumption origins are unique and restricted to outgoing non-reversal headers', async (t) => {
  const db = await legacy(t); await migrate(db, migrations);
  await db.execute("INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih) VALUES (1,'2026-10-03',1)");
  await assert.rejects(db.execute("INSERT INTO stok(id_user,jenis_stok,id_penyemaian) VALUES (1,'masuk',1)"), /HEADER_INVALID/);
  await db.execute("INSERT INTO stok(id_user,jenis_stok,id_penyemaian) VALUES (1,'keluar',1)");
  await assert.rejects(db.execute("INSERT INTO stok(id_user,jenis_stok,id_penyemaian) VALUES (1,'keluar',1)"), /UNIQUE/);
  await assert.rejects(db.execute("INSERT INTO stok(id_user,jenis_stok,id_penyemaian,id_perawatan) VALUES (1,'keluar',1,1)"), /HEADER_INVALID/);
});

test('reversal constraints enforce one opposite movement and exact copied details', async (t) => {
  const db = await legacy(t); await movement(db, 'masuk', '1'); await migrate(db, migrations);
  await assert.rejects(db.execute("INSERT INTO stok(id_user,jenis_stok,reversal_of,keterangan) VALUES (1,'masuk',1,'reason')"), /REVERSAL_INVALID/);
  await assert.rejects(db.execute("INSERT INTO stok(id_user,jenis_stok,reversal_of) VALUES (1,'keluar',1)"), /REVERSAL_INVALID/);
  await db.execute("INSERT INTO stok(id_user,jenis_stok,reversal_of,keterangan) VALUES (1,'keluar',1,'reason')");
  await db.execute("INSERT INTO detail_stok(id_stok,id_inventaris,jumlah,jumlah_minor,satuan) VALUES (2,1,0.5,50,'kg')");
  await assert.rejects(db.execute('UPDATE stok SET sealed=1 WHERE id_stok=2'), /REVERSAL_LINES_INVALID/);
  await assert.rejects(db.execute("INSERT INTO stok(id_user,jenis_stok,reversal_of,keterangan) VALUES (1,'keluar',1,'other')"), /UNIQUE/);
  // Raw SQL cannot repair the draft by editing details; rollback is the normal recovery.
  await assert.rejects(db.execute('UPDATE detail_stok SET jumlah=1,jumlah_minor=100 WHERE id_stok=2'), /IMMUTABLE/);
});

test('empty-stock down preserves prior rows and non-stock metadata and can reapply', async (t) => {
  const db = await legacy(t); const before = await fingerprint(db); const structure = await schema(db);
  await migrate(db, migrations);
  await migrate(db, migrations, { direction: 'down', allowDataLoss: true });
  assert.deepEqual(await fingerprint(db), before);
  assert.deepEqual(await schema(db), structure);
  await migrate(db, migrations);
  assert.deepEqual(await migrate(db, migrations), []);
});
for (const [name, sql] of [
  ['unbound mapping', "INSERT INTO sync_id_maps VALUES (1,'stok','12345678-1234-4234-8234-123456789abc','12345678-1234-4234-8234-123456789abd',1)"],
  ['version', "INSERT INTO sync_resource_versions VALUES ('stok','12345678-1234-4234-8234-123456789abc',1,1)"],
  ['identity', "INSERT INTO sync_resource_links VALUES ('stok','1','12345678-1234-4234-8234-123456789abc')"],
  ['receipt', `INSERT INTO sync_operations(id_user,operation_key,operation_type,payload_hash,result_json,created_at)
    VALUES (1,'12345678-1234-4234-8234-123456789abc','stok.create','${'b'.repeat(64)}','{}',1)`],
  ['projection', 'INSERT INTO stok_saldo VALUES (1,0)'],
]) {
  test(`stock down refuses ${name} even without a header`, async (t) => {
    const db = await legacy(t); await migrate(db, migrations); await db.execute(sql);
    const before = await fingerprint(db); const structure = await schema(db);
    await assert.rejects(migrate(db, migrations, { direction: 'down', allowDataLoss: true }), /b006_down_requires_empty_stock/);
    assert.deepEqual(await fingerprint(db), before); assert.deepEqual(await schema(db), structure);
  });
}
