import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildApp } from '../src/app.js';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { bootstrapPetani } from '../src/features/auth/bootstrap.js';

const migrations = await loadMigrations();
const baseConfig = {
  environment: 'test',
  host: '127.0.0.1',
  port: 0,
  databaseUrl: ':memory:',
  databaseAuthToken: undefined,
  logLevel: 'silent',
  origins: [],
  proxies: [],
  proxyHops: undefined,
};

async function setup(t, nowMs = Date.parse('2026-11-20T03:00:00Z')) {
  const db = await openDatabase({ url: ':memory:' });
  await migrate(db, migrations);
  await bootstrapPetani(db, {
    nama: 'Budi Petani',
    username: 'petani',
    password: 'Password123456!',
  });
  let now = nowMs;
  const app = buildApp({ db, config: baseConfig, clock: () => now });
  t.after(async () => {
    await app.close();
  });
  const login = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: { username: 'petani', password: 'Password123456!' },
  });
  assert.equal(login.statusCode, 200);
  const token = login.json().data.access_token;
  return { db, app, token, setNow: (v) => { now = v; } };
}

test('notifications requires authentication', async (t) => {
  const { app } = await setup(t);
  const res = await app.inject({ method: 'GET', url: '/api/v1/notifications' });
  assert.equal(res.statusCode, 401);
  const resRead = await app.inject({ method: 'POST', url: '/api/v1/notifications/read-all' });
  assert.equal(resRead.statusCode, 401);
});

test('notifications returns ready seedlings, low stock, and harvest-ready items and persists read-all', async (t) => {
  const { db, app, token } = await setup(t);
  const auth = { authorization: `Bearer ${token}` };

  // Empty farm -> 0 notifications
  const empty = await app.inject({ method: 'GET', url: '/api/v1/notifications', headers: auth });
  assert.equal(empty.statusCode, 200);
  assert.deepEqual(empty.json().data, { unread_count: 0, items: [] });

  // Seed ready nursery (HSS 17 on 2026-11-20), low-stock inventory, and harvest-ready transfer (HST 46)
  await db.execute({
    sql: "INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian) VALUES (1, '2026-11-03', 100, 'aktif')",
  });
  await db.execute({ sql: "INSERT INTO jenis_inventaris (nama_jenis) VALUES ('Benih')" });
  await db.execute({
    sql: "INSERT INTO inventaris (id_jenis_inventaris, nama_barang, satuan, stok_minimum, stok_minimum_minor, status_aktif) VALUES (1, 'Benih Romaine', 'pak', 5, 500, 1)",
  });
  await db.execute({
    sql: 'INSERT INTO stok_saldo (id_inventaris, saldo_minor) VALUES (1, 200)',
  });
  await db.execute({
    sql: "INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja) VALUES ('Meja A1', 100, 'tersedia')",
  });
  await db.execute({
    sql: "INSERT INTO pemindahan (id_penyemaian, id_meja, tanggal_pemindahan, jumlah_tanaman) VALUES (1, 1, '2026-10-05', 40)",
  });

  const beforeRead = await app.inject({ method: 'GET', url: '/api/v1/notifications', headers: auth });
  assert.equal(beforeRead.statusCode, 200);
  const data = beforeRead.json().data;
  assert.equal(data.unread_count, 3);
  assert.equal(data.items.length, 3);
  assert.deepEqual(
    data.items.map((i) => i.category).sort(),
    ['harvest', 'inventory', 'nursery'],
  );
  assert.ok(data.items.every((i) => i.read === false));

  // Mark all read
  const markRes = await app.inject({ method: 'POST', url: '/api/v1/notifications/read-all', headers: auth });
  assert.equal(markRes.statusCode, 200);
  assert.deepEqual(markRes.json().data, { marked_count: 3, unread_count: 0 });

  // Subsequent GET shows all items as read
  const afterRead = await app.inject({ method: 'GET', url: '/api/v1/notifications', headers: auth });
  assert.equal(afterRead.statusCode, 200);
  assert.equal(afterRead.json().data.unread_count, 0);
  assert.ok(afterRead.json().data.items.every((i) => i.read === true));
});

test('migration 0022 notification_reads rolls back and re-applies cleanly', async (t) => {
  const db = await openDatabase({ url: ':memory:' });
  t.after(() => db.close());
  await migrate(db, migrations);
  await migrate(db, migrations, { direction: 'down', allowDataLoss: true });
  const afterDown = await db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='notification_reads'");
  assert.equal(afterDown.rows.length, 0);
  await migrate(db, migrations);
  const afterUp = await db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='notification_reads'");
  assert.equal(afterUp.rows.length, 1);
});
