// B18, local only: the whole cycle over a real socket, through the serverless handler, on a file database.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { jakartaDate } from '../src/common/dates.ts';
import { backupDatabase, openDatabase } from '../src/db/client.ts';
import { loadMigrations, migrate, migrationStatus } from '../src/db/migrate.ts';
import { seed, SEED_CREDENTIALS } from '../src/db/seed.ts';
import { reconcileStock } from '../src/features/stock/reconcile.ts';
import { createHandler, openServerlessApp } from '../src/serverless.ts';

const DAY = 24 * 60 * 60 * 1000;
const dateAgo = (days) => jakartaDate(Date.now() - days * DAY);

async function localDeployment(t) {
  const directory = await mkdtemp(join(tmpdir(), 'hidrosense-flow-'));
  const file = join(directory, 'flow.db');
  const url = `file:${file.replaceAll('\\', '/')}`;
  const saved = { ...process.env };
  Object.assign(process.env, { DATABASE_URL: url, NODE_ENV: 'development', LOG_LEVEL: 'silent' });
  delete process.env.TRUST_PROXY_HOPS;
  delete process.env.TRUSTED_PROXIES;
  const setup = await openDatabase({ url });
  await migrate(setup, await loadMigrations());
  await seed(setup);
  setup.close();

  const apps = [];
  const servers = [];
  const startInstance = async () => {
    const handler = createHandler(async () => {
      const app = await openServerlessApp();
      apps.push(app);
      return app;
    });
    const server = createServer(handler);
    servers.push(server);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    return `http://127.0.0.1:${server.address().port}`;
  };
  t.after(async () => {
    for (const server of servers) { server.closeAllConnections(); await new Promise((resolve) => server.close(resolve)); }
    for (const app of apps) await app.close();
    for (const key of Object.keys(process.env)) if (!(key in saved)) delete process.env[key];
    Object.assign(process.env, saved);
    await rm(directory, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }).catch(() => {});
  });
  return { url, directory, startInstance };
}

function client(base) {
  let token;
  const call = async (method, path, body, headers = {}) => {
    const response = await fetch(`${base}/api/v1${path}`, {
      method,
      headers: {
        ...(token ? { authorization: `Bearer ${token}` } : {}),
        ...(body ? { 'content-type': 'application/json' } : {}),
        ...headers,
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await response.text();
    return { status: response.status, json: text ? JSON.parse(text) : null };
  };
  return {
    login: async (account) => {
      const response = await call('POST', '/auth/login', { username: account.username, password: account.password });
      assert.equal(response.status, 200);
      token = response.json.data.access_token;
    },
    get: (path) => call('GET', path),
    send: (method, path, body, key = randomUUID()) => call(method, path, body, { 'idempotency-key': key }),
  };
}

function expectStatus(response, status, code) {
  assert.equal(response.status, status, JSON.stringify(response.json));
  if (code) assert.equal(response.json.error.code, code);
  return response.json;
}

test('the whole farm cycle holds together over HTTP on a local database', async (t) => {
  const { url, directory, startInstance } = await localDeployment(t);
  const base = await startInstance();
  assert.equal((await fetch(`${base}/health/ready`)).status, 200);
  const petani = client(base);
  const pegawai = client(base);
  await petani.login(SEED_CREDENTIALS.petani);
  await pegawai.login(SEED_CREDENTIALS.pegawai);

  // Stock in, then a sowing that consumes seed. Seed item 1 starts at 1000 gram.
  expectStatus(await pegawai.send('POST', '/stok', { jenis_stok: 'masuk', details: [{ id_inventaris: '1', jumlah: '50', satuan: 'gram' }] }), 201);
  const sowingBody = { tanggal_semai: dateAgo(40), jumlah_benih: 200, materials: [{ id_inventaris: '1', jumlah: '10.5', satuan: 'gram' }] };
  const sowingKey = randomUUID();
  const sowing = expectStatus(await pegawai.send('POST', '/penyemaian', sowingBody, sowingKey), 201).data;
  // The response was lost, so the phone sends the same operation again.
  const sowingRetry = expectStatus(await pegawai.send('POST', '/penyemaian', sowingBody, sowingKey), 200);
  assert.equal(sowingRetry.replayed, true);
  assert.equal(sowingRetry.data.id_penyemaian, sowing.id_penyemaian);
  assert.equal(expectStatus(await pegawai.get('/inventaris/1/saldo'), 200).data.saldo, '1039.5');

  // Parent before child: the transfer uses the id the replay returned.
  const table = expectStatus(await pegawai.send('POST', '/meja-tanam', { kode_meja: 'ALUR-1', jumlah_lubang: 150 }), 201).data;
  expectStatus(await pegawai.send('POST', '/pemindahan', { id_penyemaian: sowingRetry.data.id_penyemaian, id_meja: table.id_meja, tanggal_pemindahan: dateAgo(20), jumlah_tanaman: 151 }), 409, 'TABLE_CAPACITY_EXCEEDED');
  const transfer = expectStatus(await pegawai.send('POST', '/pemindahan', { id_penyemaian: sowing.id_penyemaian, id_meja: table.id_meja, tanggal_pemindahan: dateAgo(20), jumlah_tanaman: 100 }), 201).data;

  // Damage against the batch.
  expectStatus(await pegawai.send('POST', '/kerusakan', { id_pemindahan: transfer.id_pemindahan, tanggal_kejadian: dateAgo(5), jumlah_tanaman: 5, jenis_kerusakan: 'busuk' }), 201);

  // Harvest: 100 moved - 5 damaged - 20 harvested leaves 75 active, so 150 - 75 = 75 holes free.
  const harvest = expectStatus(await pegawai.send('POST', '/panen', {
    tanggal_panen: dateAgo(1), details: [{ id_pemindahan: transfer.id_pemindahan, jumlah_tanaman: 20, berat_total: '9.00', berat_reject: '1.00' }],
  }), 201).data;
  assert.equal(harvest.berat_layak, '8.00');
  const tableAfter = expectStatus(await pegawai.get(`/meja-tanam/${table.id_meja}`), 200).data;
  assert.deepEqual([tableAfter.tanaman_aktif, tableAfter.kapasitas_tersedia, tableAfter.saldo_valid], [75, 75, true]);
  assert.equal(expectStatus(await pegawai.get(`/pemindahan/${transfer.id_pemindahan}`), 200).data.tanaman_aktif, 75);
  const sowingAfter = expectStatus(await pegawai.get(`/penyemaian/${sowing.id_penyemaian}`), 200).data;
  assert.equal(sowingAfter.sisa_benih, 100);

  // Sale: 5.00 kg x 20000 = 100000.00, and only 3.00 kg of the 8.00 kg remains.
  const saleBody = (kg) => ({ tanggal_penjualan: dateAgo(0), pembeli: 'Pasar Ambulu', status_pembayaran: 'lunas', id_panen: harvest.id_panen, jumlah_kg: kg, harga_per_kg: '20000.00' });
  const sale = expectStatus(await petani.send('POST', '/penjualan', saleBody('5.00')), 201).data;
  assert.equal(sale.details[0].total_harga, '100000.00');
  expectStatus(await petani.send('POST', '/penjualan', saleBody('3.01')), 409, 'SALE_EXCEEDS_HARVEST_STOCK');
  expectStatus(await petani.send('POST', '/penjualan', saleBody('3.00')), 201);
  expectStatus(await pegawai.send('POST', '/penjualan', saleBody('0.01')), 403);
  expectStatus(await pegawai.get('/penjualan'), 403);

  // A second device catches up from the feed; two devices then race on one record.
  const feed = expectStatus(await pegawai.get('/sync/changes?limit=200'), 200);
  const types = feed.data.map((row) => row.resource_type);
  for (const type of ['penyemaian', 'meja-tanam', 'pemindahan', 'kerusakan_tanaman', 'panen', 'stok', 'inventaris']) assert.ok(types.includes(type), type);
  assert.equal(types.includes('penjualan'), false);
  const version = tableAfter.version;
  expectStatus(await petani.send('PATCH', `/meja-tanam/${table.id_meja}`, { keterangan: 'perangkat A', expected_version: version }), 200);
  expectStatus(await pegawai.send('PATCH', `/meja-tanam/${table.id_meja}`, { keterangan: 'perangkat B', expected_version: version }), 409, 'VERSION_CONFLICT');
  const caughtUp = expectStatus(await pegawai.get(`/sync/changes?cursor=${feed.meta.next_cursor}`), 200);
  assert.deepEqual(caughtUp.data.map((row) => `${row.resource_type}:${row.domain_id}`), [`meja-tanam:${table.id_meja}`]);

  // A second function instance sees the same data and the same IP quota store.
  const otherInstance = client(await startInstance());
  await otherInstance.login(SEED_CREDENTIALS.petani);
  assert.equal(expectStatus(await otherInstance.get(`/penjualan/${sale.id_penjualan}`), 200).data.pembeli, 'Pasar Ambulu');

  // Ledger and balance agree, in the live database and in a restored backup.
  const db = await openDatabase({ url });
  t.after(() => db.close());
  const reconciled = await reconcileStock(db);
  assert.equal(reconciled.consistent, true, JSON.stringify(reconciled.mismatches));
  const backupPath = await backupDatabase(db, join(directory, 'restore.db'));
  const restored = await openDatabase({ url: `file:${backupPath.replaceAll('\\', '/')}` });
  t.after(() => restored.close());
  assert.ok((await migrationStatus(restored, await loadMigrations())).every((item) => item.status === 'applied'));
  assert.equal((await reconcileStock(restored)).consistent, true);
  const count = async (database, table) => Number((await database.execute(`SELECT COUNT(*) AS n FROM ${table}`)).rows[0].n);
  for (const name of ['penjualan', 'panen', 'sync_changes', 'sync_operations']) {
    assert.equal(await count(restored, name), await count(db, name), name);
  }
});

test('every migration runs up, all the way down, and up again', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const all = await loadMigrations();
  assert.equal((await migrate(db, all)).length, all.length);
  for (let i = 0; i < all.length; i += 1) await migrate(db, all, { direction: 'down', allowDataLoss: true });
  assert.ok((await migrationStatus(db, all)).every((item) => item.status === 'pending'));
  assert.equal((await migrate(db, all)).length, all.length);
  assert.equal((await db.execute('PRAGMA foreign_key_check')).rows.length, 0);
});

test('a seeded database survives the last migrations going down and up', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  const all = await loadMigrations();
  await migrate(db, all);
  await seed(db);
  const before = Number((await db.execute('SELECT COUNT(*) AS n FROM pemindahan')).rows[0].n);
  for (let i = 0; i < 3; i += 1) await migrate(db, all, { direction: 'down', allowDataLoss: true });
  await migrate(db, all);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS n FROM pemindahan')).rows[0].n), before);
  assert.equal((await db.execute('PRAGMA foreign_key_check')).rows.length, 0);
});
