import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildApp } from '../src/app.ts';
import { readConfig } from '../src/config.ts';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { seed, SEED_CREDENTIALS } from '../src/db/seed.js';

async function setup(t) {
  const db = await openDatabase({ url: ':memory:' });
  await migrate(db, await loadMigrations());

  const now = Date.parse('2026-10-07T08:00:00Z');
  const clock = () => now;
  const config = readConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent' });
  const app = buildApp({ db, config, clock });

  t.after(async () => {
    await app.close();
    db.close();
  });

  return { app, db, clock };
}

test('seed populates accounts and authenticates both petani and pegawai via /api/v1/auth/login', async (t) => {
  const { app, db, clock } = await setup(t);
  const result = await seed(db, { clock });
  assert.equal(result.success, true);
  assert.deepEqual(result.seededUsers, ['petani', 'pegawai']);

  // 1. Test Petani Login
  const petaniLogin = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: {
      username: SEED_CREDENTIALS.petani.username,
      password: SEED_CREDENTIALS.petani.password,
    },
  });
  assert.equal(petaniLogin.statusCode, 200, petaniLogin.body);
  const petaniData = petaniLogin.json().data;
  assert.ok(petaniData.access_token);
  assert.ok(petaniData.refresh_token);
  assert.equal(petaniData.user.username, 'petani');
  assert.equal(petaniData.user.role, 'petani');
  assert.ok(petaniData.user.permissions.includes('pegawai:manage'));
  assert.ok(petaniData.user.permissions.includes('budidaya:read'));

  // 2. Test Pegawai Login
  const pegawaiLogin = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: {
      username: SEED_CREDENTIALS.pegawai.username,
      password: SEED_CREDENTIALS.pegawai.password,
    },
  });
  assert.equal(pegawaiLogin.statusCode, 200, pegawaiLogin.body);
  const pegawaiData = pegawaiLogin.json().data;
  assert.ok(pegawaiData.access_token);
  assert.ok(pegawaiData.refresh_token);
  assert.equal(pegawaiData.user.username, 'pegawai');
  assert.equal(pegawaiData.user.role, 'pegawai');
  assert.ok(pegawaiData.user.permissions.includes('budidaya:write'));
  assert.ok(pegawaiData.user.permissions.includes('penyemaian:write'));
  assert.ok(pegawaiData.user.permissions.includes('inventaris:write'));

  // 3. Test Invalid Password fails with 401
  const badLogin = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: {
      username: 'petani',
      password: 'WrongPassword123!',
    },
  });
  assert.equal(badLogin.statusCode, 401);
  assert.equal(badLogin.json().error.code, 'INVALID_CREDENTIALS');
});

test('seed populates comprehensive domain data across B005–B009 features and sync links', async (t) => {
  const { app, db, clock } = await setup(t);
  await seed(db, { clock });

  // Login as pegawai to query domain APIs
  const login = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: {
      username: SEED_CREDENTIALS.pegawai.username,
      password: SEED_CREDENTIALS.pegawai.password,
    },
  });
  const headers = { authorization: `Bearer ${login.json().data.access_token}` };

  // 1. Inventory & Stock (B005 & B006)
  const items = (await app.inject({ method: 'GET', url: '/api/v1/inventaris', headers })).json().data;
  assert.equal(items.length, 5);

  const stockBalance = (await app.inject({ method: 'GET', url: '/api/v1/inventaris/1/saldo', headers })).json().data;
  assert.equal(stockBalance.saldo, '1000'); // 1000 gram

  // 2. Nursery (B007)
  const sowings = (await app.inject({ method: 'GET', url: '/api/v1/penyemaian', headers })).json().data;
  assert.equal(sowings.length, 2);
  const readySowing = sowings.find((s) => s.id_penyemaian === '1');
  assert.equal(readySowing.siap_pindah, true); // Age 20 days >= 15 days

  // 3. Tables (B008)
  const tables = (await app.inject({ method: 'GET', url: '/api/v1/meja-tanam', headers })).json().data;
  assert.equal(tables.length, 4);
  const table1 = tables.find((m) => m.id_meja === '1');
  assert.equal(table1.kode_meja, 'M-01');
  assert.equal(table1.tanaman_aktif, 200); // 200 seedlings transferred
  assert.equal(table1.kapasitas_tersedia, 50); // 250 - 200 = 50

  // 4. Seedling Transfers (B009)
  const transfers = (await app.inject({ method: 'GET', url: '/api/v1/pemindahan', headers })).json().data;
  assert.equal(transfers.length, 1);
  const transfer1 = transfers[0];
  assert.equal(transfer1.id_penyemaian, '1');
  assert.equal(transfer1.id_meja, '1');
  assert.equal(transfer1.jumlah_tanaman, 200);
  assert.equal(transfer1.umur_semai_hari, 15);
  // Harvest estimation: Sowing date (now - 20 days: 2026-09-17) + 45 days = 2026-11-01
  assert.ok(transfer1.estimasi_panen);
  assert.ok(transfer1.public_id);
  assert.equal(transfer1.version, '1');

  // 5. Verify sync resource links exist in db
  const syncLinks = (await db.execute('SELECT COUNT(*) AS total FROM sync_resource_links')).rows[0].total;
  assert.ok(Number(syncLinks) >= 15);
});

test('seed is completely idempotent: multiple consecutive runs succeed and refresh data cleanly', async (t) => {
  const { app, db, clock } = await setup(t);

  // Run 1
  await seed(db, { clock });

  // Run 2 (immediate consecutive execution)
  const rerun = await seed(db, { clock });
  assert.equal(rerun.success, true);

  // Re-authenticating both users succeeds without conflict
  for (const role of ['petani', 'pegawai']) {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: {
        username: SEED_CREDENTIALS[role].username,
        password: SEED_CREDENTIALS[role].password,
      },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json().data.user.role, role);
  }

  // Domain data remains intact and consistent
  const usersCount = (await db.execute('SELECT COUNT(*) AS total FROM users')).rows[0].total;
  assert.equal(Number(usersCount), 2);

  const tablesCount = (await db.execute('SELECT COUNT(*) AS total FROM meja_tanam')).rows[0].total;
  assert.equal(Number(tablesCount), 4);
});
