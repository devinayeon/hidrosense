// B17 / PB-07: another device asks what changed since its last cursor, then re-reads those records.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { seed, SEED_CREDENTIALS } from '../src/db/seed.ts';
import { buildApp } from '../src/app.ts';
import { readConfig } from '../src/config.ts';
import { bearer, fixture } from '../test-support/fixture.js';

async function setup(t) {
  const f = await fixture(t);
  const petani = bearer((await f.login('petani')).json().data.access_token);
  const pegawai = bearer((await f.login('pegawai')).json().data.access_token);
  const changes = (headers, query = '') => f.app.inject({ url: `/api/v1/sync/changes${query}`, headers });
  const write = (headers, method, url, payload) => f.app.inject({ method, url: `/api/v1${url}`, headers, payload });
  return { ...f, petani, pegawai, changes, write };
}

const kinds = (response) => response.json().data.map((row) => `${row.resource_type}:${row.domain_id}`);

function assertOk(response, status = 200) {
  assert.equal(response.statusCode, status, response.body);
  return response;
}

// Inventory item, stock in, sowing old enough to transfer, table, transfer.
async function batch(f) {
  const { write, petani } = f;
  const jenis = assertOk(await write(petani, 'POST', '/jenis-inventaris', { nama_jenis: 'Benih' }), 201).json().data.id_jenis_inventaris;
  const item = assertOk(await write(petani, 'POST', '/inventaris', { id_jenis_inventaris: jenis, nama_barang: 'Benih A', satuan: 'gram' }), 201).json().data.id_inventaris;
  assertOk(await write(petani, 'POST', '/stok', { jenis_stok: 'masuk', details: [{ id_inventaris: item, jumlah: '100', satuan: 'gram' }] }), 201);
  const sowing = assertOk(await write(petani, 'POST', '/penyemaian', { tanggal_semai: '2026-09-01', jumlah_benih: 50, materials: [{ id_inventaris: item, jumlah: '1', satuan: 'gram' }] }), 201).json().data.id_penyemaian;
  const table = assertOk(await write(petani, 'POST', '/meja-tanam', { kode_meja: 'M1', jumlah_lubang: 100 }), 201).json().data.id_meja;
  const transfer = assertOk(await write(petani, 'POST', '/pemindahan', { id_penyemaian: sowing, id_meja: table, tanggal_pemindahan: '2026-09-20', jumlah_tanaman: 20 }), 201).json().data.id_pemindahan;
  return { item, sowing, table, transfer };
}

test('a first pull returns every record with identity and version', async (t) => {
  const f = await setup(t);
  const { item } = await batch(f);
  const response = assertOk(await f.changes(f.petani));
  const rows = response.json().data;
  const row = rows.find((entry) => entry.resource_type === 'inventaris' && entry.domain_id === item);
  assert.ok(row.public_id);
  assert.equal(row.version, '1');
  assert.equal(row.changed_at, '2026-09-30T00:00:00.000Z');
  assert.ok(Number(row.cursor) > 0);
  assert.equal(response.json().meta.has_more, false);
  assert.equal(response.json().meta.next_cursor, rows.at(-1).cursor);
});

test('a later pull returns only what changed, once per record', async (t) => {
  const f = await setup(t);
  const { table } = await batch(f);
  const cursor = assertOk(await f.changes(f.petani)).json().meta.next_cursor;
  assert.deepEqual(assertOk(await f.changes(f.petani, `?cursor=${cursor}`)).json().data, []);
  assert.equal(assertOk(await f.changes(f.petani, `?cursor=${cursor}`)).json().meta.next_cursor, cursor);
  assertOk(await f.write(f.petani, 'PATCH', `/meja-tanam/${table}`, { keterangan: 'a' }));
  assertOk(await f.write(f.petani, 'PATCH', `/meja-tanam/${table}`, { keterangan: 'b' }));
  const response = assertOk(await f.changes(f.petani, `?cursor=${cursor}`));
  assert.deepEqual(kinds(response), [`meja-tanam:${table}`]);
  // Created at 1, plus two edits.
  assert.equal(response.json().data[0].version, '3');
});

test('pages never lose a change, even when a record changes between pages', async (t) => {
  const f = await setup(t);
  await batch(f);
  const seen = new Map();
  let cursor = '0';
  let pages = 0;
  let edited = false;
  for (;;) {
    const page = assertOk(await f.changes(f.petani, `?limit=2&cursor=${cursor}`)).json();
    assert.ok(page.data.length <= 2);
    for (const row of page.data) seen.set(`${row.resource_type}:${row.domain_id}`, row.version);
    cursor = page.meta.next_cursor;
    pages += 1;
    if (!edited) {
      edited = true;
      assertOk(await f.write(f.petani, 'PATCH', '/meja-tanam/1', { keterangan: 'di tengah' }));
    }
    if (!page.meta.has_more) break;
    assert.ok(pages < 50);
  }
  assert.equal(seen.get('meja-tanam:1'), '2');
  for (const expected of ['jenis-inventaris:1', 'inventaris:1', 'stok:1', 'penyemaian:1', 'pemindahan:1']) assert.ok(seen.has(expected), expected);
});

test('values derived from another record are announced too', async (t) => {
  const f = await setup(t);
  const { item, sowing, table, transfer } = await batch(f);
  const start = async () => assertOk(await f.changes(f.petani)).json().meta.next_cursor;

  // Stock movement changes the item's balance.
  let cursor = await start();
  assertOk(await f.write(f.petani, 'POST', '/stok', { jenis_stok: 'masuk', details: [{ id_inventaris: item, jumlah: '5', satuan: 'gram' }] }), 201);
  assert.ok(kinds(assertOk(await f.changes(f.petani, `?cursor=${cursor}`))).includes(`inventaris:${item}`));

  // Damage changes active plants on the batch and capacity on the table.
  cursor = await start();
  const damage = assertOk(await f.write(f.petani, 'POST', '/kerusakan', { id_pemindahan: transfer, tanggal_kejadian: '2026-09-25', jumlah_tanaman: 1, jenis_kerusakan: 'busuk' }), 201).json().data.id_kerusakan;
  let changed = kinds(assertOk(await f.changes(f.petani, `?cursor=${cursor}`)));
  for (const expected of [`kerusakan_tanaman:${damage}`, `pemindahan:${transfer}`, `meja-tanam:${table}`]) assert.ok(changed.includes(expected), expected);

  cursor = await start();
  assertOk(await f.write(f.petani, 'PATCH', `/kerusakan/${damage}`, { jumlah_tanaman: 2 }));
  changed = kinds(assertOk(await f.changes(f.petani, `?cursor=${cursor}`)));
  for (const expected of [`pemindahan:${transfer}`, `meja-tanam:${table}`]) assert.ok(changed.includes(expected), expected);

  // A harvest does the same.
  cursor = await start();
  assertOk(await f.write(f.petani, 'POST', '/panen', { tanggal_panen: '2026-09-28', details: [{ id_pemindahan: transfer, jumlah_tanaman: 3, berat_total: '1.00', berat_reject: '0.00' }] }), 201);
  changed = kinds(assertOk(await f.changes(f.petani, `?cursor=${cursor}`)));
  for (const expected of ['panen:1', `pemindahan:${transfer}`, `meja-tanam:${table}`]) assert.ok(changed.includes(expected), expected);

  // A transfer changes the seedlings left on its sowing and the table.
  cursor = await start();
  assertOk(await f.write(f.petani, 'POST', '/pemindahan', { id_penyemaian: sowing, id_meja: table, tanggal_pemindahan: '2026-09-21', jumlah_tanaman: 30 }), 201);
  changed = kinds(assertOk(await f.changes(f.petani, `?cursor=${cursor}`)));
  for (const expected of [`penyemaian:${sowing}`, `meja-tanam:${table}`]) assert.ok(changed.includes(expected), expected);
});

test('a derived change does not bump the version, so it cannot cause a false conflict', async (t) => {
  const f = await setup(t);
  const { table, transfer } = await batch(f);
  assertOk(await f.write(f.petani, 'POST', '/kerusakan', { id_pemindahan: transfer, tanggal_kejadian: '2026-09-25', jumlah_tanaman: 1, jenis_kerusakan: 'busuk' }), 201);
  const edit = await f.write(f.petani, 'PATCH', `/meja-tanam/${table}`, { keterangan: 'x', expected_version: '1' });
  assert.equal(edit.statusCode, 200, edit.body);
});

test('a retried write adds no second change, and a failed write adds none', async (t) => {
  const f = await setup(t);
  const { table } = await batch(f);
  const cursor = assertOk(await f.changes(f.petani)).json().meta.next_cursor;
  const headers = { ...f.petani, 'idempotency-key': '11111111-1111-4111-8111-111111111111' };
  assertOk(await f.write(headers, 'PATCH', `/meja-tanam/${table}`, { keterangan: 'a' }));
  const count = async () => Number((await f.db.execute({ sql: 'SELECT COUNT(*) AS n FROM sync_changes WHERE id_change>?', args: [cursor] })).rows[0].n);
  const after = await count();
  assert.equal((await f.write(headers, 'PATCH', `/meja-tanam/${table}`, { keterangan: 'a' })).json().replayed, true);
  assert.equal(await count(), after);
  assert.equal((await f.write(f.petani, 'PATCH', `/meja-tanam/${table}`, { keterangan: 'b', expected_version: '99' })).statusCode, 409);
  assert.equal(await count(), after);
});

test('pegawai never learns about sales through the feed', async (t) => {
  const f = await setup(t);
  const { transfer } = await batch(f);
  assertOk(await f.write(f.petani, 'POST', '/panen', { tanggal_panen: '2026-09-28', details: [{ id_pemindahan: transfer, jumlah_tanaman: 3, berat_total: '1.00', berat_reject: '0.00' }] }), 201);
  assertOk(await f.write(f.petani, 'POST', '/penjualan', { tanggal_penjualan: '2026-09-29', pembeli: 'Toko', status_pembayaran: 'lunas', id_panen: '1', jumlah_kg: '0.50', harga_per_kg: '1000.00' }), 201);
  const owner = assertOk(await f.changes(f.petani)).json().data.map((row) => row.resource_type);
  assert.ok(owner.includes('penjualan'));
  const worker = assertOk(await f.changes(f.pegawai)).json().data.map((row) => row.resource_type);
  assert.equal(worker.includes('penjualan'), false);
  assert.ok(worker.includes('panen'));
});

test('a record type the feed does not know stays hidden from everyone', async (t) => {
  const f = await setup(t);
  await f.db.execute("INSERT INTO sync_changes(resource_type,domain_id,changed_at) VALUES ('rahasia','1',1)");
  assert.equal(kinds(assertOk(await f.changes(f.petani))).includes('rahasia:1'), false);
});

test('bad requests and anonymous callers are refused', async (t) => {
  const f = await setup(t);
  assert.equal((await f.app.inject('/api/v1/sync/changes')).statusCode, 401);
  for (const query of ['?cursor=-1', '?cursor=abc', '?cursor=01', '?limit=0', '?limit=201', '?lain=1']) {
    assert.equal((await f.changes(f.petani, query)).statusCode, 400, query);
  }
});

test('a cursor ahead of the server asks the client to start over', async (t) => {
  const f = await setup(t);
  await batch(f);
  const response = await f.changes(f.petani, '?cursor=999999');
  assert.equal(response.statusCode, 409, response.body);
  assert.equal(response.json().error.code, 'SYNC_CURSOR_RESET');
});

test('seeded and already existing records reach the feed', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  await migrate(db, await loadMigrations());
  const clock = () => Date.parse('2026-10-07T08:00:00Z');
  await seed(db, { clock });
  const app = buildApp({ db, config: readConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent' }), clock });
  t.after(() => app.close());
  const login = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'petani', password: SEED_CREDENTIALS.petani.password } });
  const headers = bearer(login.json().data.access_token);
  const before = (await app.inject({ url: '/api/v1/sync/changes?limit=200', headers })).json().data;
  assert.equal(before.length, 19);
  // Re-seeding changes nothing, so it announces nothing.
  await seed(db, { clock });
  const cursor = before.at(-1).cursor;
  assert.deepEqual((await app.inject({ url: `/api/v1/sync/changes?cursor=${cursor}`, headers })).json().data, []);
});

test('migration backfills existing records and rolls back', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const all = await loadMigrations();
  const index = all.findIndex((migration) => migration.id.endsWith('_sync_changes'));
  assert.ok(index > 0);
  await migrate(db, all.slice(0, index));
  await db.execute("INSERT INTO jenis_inventaris(nama_jenis) VALUES ('Lama')");
  await db.execute("INSERT INTO sync_resource_links(resource_type,domain_id,public_id) VALUES ('jenis-inventaris','1','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')");
  await db.execute("INSERT INTO sync_resource_versions(resource_type,public_id,version,changed_at) VALUES ('jenis-inventaris','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',4,123)");
  await migrate(db, all.slice(0, index + 1));
  const row = (await db.execute('SELECT resource_type,domain_id,changed_at FROM sync_changes')).rows[0];
  assert.deepEqual([row.resource_type, row.domain_id, row.changed_at], ['jenis-inventaris', '1', 123]);
  await migrate(db, all.slice(0, index + 1), { direction: 'down', allowDataLoss: true });
  assert.equal(Number((await db.execute("SELECT COUNT(*) AS n FROM sqlite_master WHERE name LIKE '%sync_changes%'")).rows[0].n), 0);
  await db.execute("UPDATE sync_resource_versions SET version=5 WHERE resource_type='jenis-inventaris'");
  await migrate(db, all.slice(0, index + 1));
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS n FROM sync_changes')).rows[0].n), 1);
});
