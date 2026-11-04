// Regression pins for outofthebox/hunt-002-2026-11-04.md and yeonworks/review-backend-hidrosense.md.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { buildApp } from '../src/app.ts';
import { jakartaDate } from '../src/common/dates.ts';
import { purgeExpiredAuthRecords } from '../src/common/maintenance.ts';
import { readConfig } from '../src/config.ts';
import { openDatabase } from '../src/db/client.js';
import { loadMigrations, migrate } from '../src/db/migrate.js';
import { seed, SEED_CREDENTIALS } from '../src/db/seed.ts';

const NOW = Date.parse('2026-10-07T08:00:00Z');

async function setup(t, appOptions = {}) {
  const db = await openDatabase({ url: ':memory:' });
  await migrate(db, await loadMigrations());
  await seed(db, { clock: () => NOW });
  const app = buildApp({ db, config: readConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent' }), clock: () => NOW, ...appOptions });
  t.after(async () => { await app.close(); });
  const login = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: {
    username: SEED_CREDENTIALS.petani.username, password: SEED_CREDENTIALS.petani.password } });
  const auth = { authorization: `Bearer ${login.json().data.access_token}` };
  const get = (url) => app.inject({ method: 'GET', url, headers: auth });
  const write = (method, url, payload, headers = {}) => app.inject({ method, url, payload,
    headers: { ...auth, 'idempotency-key': randomUUID(), ...headers } });
  return { app, db, get, write };
}

const code = (response) => response.json().error?.code;

// F1: re-running the seeder on a used database silently overwrote real rows.
test('F1 re-seeding keeps edited domain rows and account profiles', async (t) => {
  const { db } = await setup(t);
  await db.execute("UPDATE penyemaian SET jumlah_benih=777, keterangan='DATA NYATA', tanggal_semai='2026-01-01' WHERE id_penyemaian=1");
  await db.execute("UPDATE meja_tanam SET kode_meja='REAL-1', jumlah_lubang=999, status_meja='rusak' WHERE id_meja=1");
  await db.execute("UPDATE inventaris SET nama_barang='Benih Pilihan' WHERE id_inventaris=1");
  await db.execute("UPDATE jenis_inventaris SET nama_jenis='Biji' WHERE id_jenis_inventaris=1");
  await db.execute("UPDATE obat SET dosis='9 ml/L' WHERE id_obat=1");
  await db.execute("UPDATE pemindahan SET keterangan='Catatan petani' WHERE id_pemindahan=1");
  await db.execute("UPDATE users SET nama='Nama Asli', email='asli@contoh.id' WHERE username='petani'");
  const versionBefore = (await db.execute("SELECT changed_at FROM sync_resource_versions WHERE resource_type='obat' LIMIT 1")).rows[0].changed_at;

  await seed(db, { clock: () => NOW + 86400000 });

  const one = async (sql) => (await db.execute(sql)).rows[0];
  const sowing = await one('SELECT jumlah_benih,keterangan,tanggal_semai FROM penyemaian WHERE id_penyemaian=1');
  assert.deepEqual([sowing.jumlah_benih, sowing.keterangan, sowing.tanggal_semai], [777, 'DATA NYATA', '2026-01-01']);
  const table = await one('SELECT kode_meja,jumlah_lubang,status_meja FROM meja_tanam WHERE id_meja=1');
  assert.deepEqual([table.kode_meja, table.jumlah_lubang, table.status_meja], ['REAL-1', 999, 'rusak']);
  assert.equal((await one('SELECT nama_barang FROM inventaris WHERE id_inventaris=1')).nama_barang, 'Benih Pilihan');
  assert.equal((await one('SELECT nama_jenis FROM jenis_inventaris WHERE id_jenis_inventaris=1')).nama_jenis, 'Biji');
  assert.equal((await one('SELECT dosis FROM obat WHERE id_obat=1')).dosis, '9 ml/L');
  assert.equal((await one('SELECT keterangan FROM pemindahan WHERE id_pemindahan=1')).keterangan, 'Catatan petani');
  const user = await one("SELECT nama,email FROM users WHERE username='petani'");
  assert.deepEqual([user.nama, user.email], ['Nama Asli', 'asli@contoh.id']);
  assert.equal((await one("SELECT changed_at FROM sync_resource_versions WHERE resource_type='obat' LIMIT 1")).changed_at, versionBefore);
});

test('F1 re-seeding still restores a seed row that is missing', async (t) => {
  const { db } = await setup(t);
  await db.execute('DELETE FROM meja_tanam WHERE id_meja=4');
  await seed(db, { clock: () => NOW });
  assert.equal((await db.execute('SELECT kode_meja FROM meja_tanam WHERE id_meja=4')).rows[0].kode_meja, 'M-04');
});

// F2: only panen accepted expected_version, so two devices overwrote each other.
const versioned = [
  ['meja-tanam', '/api/v1/meja-tanam/1', { keterangan: 'baru' }],
  ['penyemaian', '/api/v1/penyemaian/1', { keterangan: 'baru' }],
  ['pemindahan', '/api/v1/pemindahan/1', { keterangan: 'baru' }],
  ['inventaris', '/api/v1/inventaris/1', { nama_barang: 'Barang baru' }],
  ['obat', '/api/v1/obat/1', { dosis: '1 ml/L' }],
  ['jenis-inventaris', '/api/v1/jenis-inventaris/1', { nama_jenis: 'Jenis baru' }],
];

for (const [name, url, change] of versioned) {
  test(`F2 ${name} refuses a stale expected_version and accepts the current one`, async (t) => {
    const { get, write } = await setup(t);
    const before = (await get(url)).json().data;
    assert.equal(before.version, '1');

    const stale = await write('PATCH', url, { ...change, expected_version: '99' });
    assert.equal(stale.statusCode, 409, stale.body);
    assert.equal(code(stale), 'VERSION_CONFLICT');
    assert.deepEqual((await get(url)).json().data, before);

    const fresh = await write('PATCH', url, { ...change, expected_version: '1' });
    assert.equal(fresh.statusCode, 200, fresh.body);
    assert.equal(fresh.json().data.version, '2');

    const late = await write('PATCH', url, { ...change, expected_version: '1' });
    assert.equal(code(late), 'VERSION_CONFLICT');
    assert.equal((await get(url)).json().data.version, '2');

    const onlyVersion = await write('PATCH', url, { expected_version: '2' });
    assert.equal(onlyVersion.statusCode, 400, onlyVersion.body);

    // The current Flutter client sends no version; it must keep working.
    const legacyClient = await write('PATCH', url, change);
    assert.equal(legacyClient.statusCode, 200, legacyClient.body);
  });
}

test('F2 kerusakan refuses a stale expected_version', async (t) => {
  const { write } = await setup(t);
  const created = await write('POST', '/api/v1/kerusakan', { id_pemindahan: '1', tanggal_kejadian: '2026-10-05', jumlah_tanaman: 1, jenis_kerusakan: 'layu' });
  assert.equal(created.statusCode, 201, created.body);
  const url = `/api/v1/kerusakan/${created.json().data.id_kerusakan}`;
  assert.equal(code(await write('PATCH', url, { keterangan: 'x', expected_version: '99' })), 'VERSION_CONFLICT');
  assert.equal((await write('PATCH', url, { keterangan: 'x', expected_version: '1' })).json().data.version, '2');
});

test('F2 a retry replays its receipt even after the version moved on', async (t) => {
  const { write } = await setup(t);
  const headers = { 'idempotency-key': randomUUID() };
  const body = { keterangan: 'a', expected_version: '1' };
  const first = await write('PATCH', '/api/v1/meja-tanam/1', body, headers);
  assert.equal(first.statusCode, 200, first.body);
  await write('PATCH', '/api/v1/meja-tanam/1', { keterangan: 'b' });
  const retry = await write('PATCH', '/api/v1/meja-tanam/1', body, headers);
  assert.equal(retry.statusCode, 200, retry.body);
  assert.equal(retry.json().replayed, true);
  assert.equal(retry.json().data.keterangan, 'a');
});

test('F2 expected_version reports a missing row as 404 and an unversioned row as a conflict', async (t) => {
  const { db, write, get } = await setup(t);
  assert.equal(code(await write('PATCH', '/api/v1/meja-tanam/999', { keterangan: 'x', expected_version: '1' })), 'TABLE_NOT_FOUND');
  await db.execute("INSERT INTO meja_tanam(id_meja,kode_meja,jumlah_lubang,status_meja) VALUES (50,'LAMA',10,'tersedia')");
  assert.equal(code(await write('PATCH', '/api/v1/meja-tanam/50', { keterangan: 'x', expected_version: '1' })), 'VERSION_CONFLICT');
  assert.equal((await get('/api/v1/meja-tanam/50')).json().data.keterangan, null);
});

// F3: one inconsistent table made the whole list fail, and the API could not repair it.
test('F3 one inconsistent table no longer blanks the list', async (t) => {
  const { db, get } = await setup(t);
  await db.execute('UPDATE meja_tanam SET jumlah_lubang=100 WHERE id_meja=1'); // 200 plants are active

  const list = await get('/api/v1/meja-tanam');
  assert.equal(list.statusCode, 200, list.body);
  const rows = list.json().data;
  assert.equal(rows.length, 4);
  const broken = rows.find((row) => row.id_meja === '1');
  assert.deepEqual([broken.saldo_valid, broken.tanaman_aktif, broken.kapasitas_tersedia], [false, 200, 0]);
  assert.equal(rows.find((row) => row.id_meja === '2').saldo_valid, true);

  assert.equal(code(await get('/api/v1/meja-tanam/1')), 'TABLE_BALANCE_INVALID');
});

test('F3 an inconsistent table can be repaired through PATCH, but only into a valid state', async (t) => {
  const { db, get, write } = await setup(t);
  await db.execute('UPDATE meja_tanam SET jumlah_lubang=100 WHERE id_meja=1');

  const stillBroken = await write('PATCH', '/api/v1/meja-tanam/1', { jumlah_lubang: 150 });
  assert.equal(code(stillBroken), 'TABLE_UNDERCAPACITY');
  const unrelated = await write('PATCH', '/api/v1/meja-tanam/1', { keterangan: 'x' });
  assert.equal(code(unrelated), 'TABLE_BALANCE_INVALID');
  assert.equal((await db.execute('SELECT keterangan FROM meja_tanam WHERE id_meja=1')).rows[0].keterangan, 'Meja NFT Blok A1');

  const repaired = await write('PATCH', '/api/v1/meja-tanam/1', { jumlah_lubang: 250 });
  assert.equal(repaired.statusCode, 200, repaired.body);
  assert.equal(repaired.json().data.kapasitas_tersedia, 50);
  assert.equal((await get('/api/v1/meja-tanam/1')).statusCode, 200);
});

// F4: nursery ignored the header silently where every sibling update refuses it.
test('F4 PATCH penyemaian refuses X-Client-Id like its sibling updates', async (t) => {
  const { write } = await setup(t);
  const header = { 'x-client-id': randomUUID() };
  assert.equal((await write('PATCH', '/api/v1/meja-tanam/1', { keterangan: 'x' }, header)).statusCode, 400);
  const nursery = await write('PATCH', '/api/v1/penyemaian/1', { keterangan: 'x' }, header);
  assert.equal(nursery.statusCode, 400, nursery.body);
});

// F5: the harvest list ran two queries per row.
test('F5 the harvest list query count does not grow with rows and matches the detail shape', async (t) => {
  const { db, get } = await setup(t);
  for (let i = 0; i < 50; i += 1) {
    const id = (await db.execute({ sql: 'INSERT INTO panen(id_user,tanggal_panen,keterangan) VALUES (1,?,?) RETURNING id_panen', args: ['2026-10-06', `h${i}`] })).rows[0].id_panen;
    for (const reject of i === 0 ? [0, null] : [25]) {
      await db.execute({ sql: 'INSERT INTO detail_panen(id_panen,id_pemindahan,jumlah_tanaman,berat,berat_minor,berat_reject_minor) VALUES (?,1,1,?,?,?)', args: [id, '1.50', 150, reject] });
    }
  }
  let queries = 0;
  const transaction = db.transaction.bind(db);
  db.transaction = async (mode) => {
    const tx = await transaction(mode);
    const execute = tx.execute.bind(tx);
    tx.execute = (...args) => { queries += 1; return execute(...args); };
    return tx;
  };
  const list = await get('/api/v1/panen?limit=50');
  db.transaction = transaction;

  assert.equal(list.statusCode, 200, list.body);
  const rows = list.json().data;
  assert.equal(rows.length, 50);
  assert.ok(queries <= 3, `expected at most 3 queries, ran ${queries}`);
  assert.equal(list.json().meta.total, 50);
  for (const row of [rows[0], rows[25], rows[49]]) {
    assert.deepEqual(row, (await get(`/api/v1/panen/${row.id_panen}`)).json().data);
  }
  // Newest id first, and the two-line harvest keeps both lines and its unknown reject total.
  const twoLines = rows[49];
  assert.equal(twoLines.keterangan, 'h0');
  assert.equal(twoLines.details.length, 2);
  assert.equal(twoLines.berat_reject, null);
  assert.equal(twoLines.berat_layak, '3.00');
});

test('F5 an empty or past-the-end harvest page stays valid', async (t) => {
  const { get } = await setup(t);
  const empty = await get('/api/v1/panen?page=9');
  assert.equal(empty.statusCode, 200, empty.body);
  assert.deepEqual(empty.json().data, []);
});

// F6: the same mistake earned a different HTTP status per feature.
test('F6 a future date is 400 on every dated create', async (t) => {
  const { write } = await setup(t);
  const future = '2026-10-10';
  const responses = [
    await write('POST', '/api/v1/penyemaian', { tanggal_semai: future, jumlah_benih: 1, materials: [{ id_inventaris: '1', jumlah: '1', satuan: 'gram' }] }),
    await write('POST', '/api/v1/pemindahan', { id_penyemaian: '1', id_meja: '2', tanggal_pemindahan: future, jumlah_tanaman: 1 }),
    await write('POST', '/api/v1/kerusakan', { id_pemindahan: '1', tanggal_kejadian: future, jumlah_tanaman: 1, jenis_kerusakan: 'x' }),
    await write('POST', '/api/v1/panen', { tanggal_panen: future, details: [{ id_pemindahan: '1', jumlah_tanaman: 1, berat_total: '1.00', berat_reject: '0.00' }] }),
  ];
  assert.deepEqual(responses.map((response) => response.statusCode), [400, 400, 400, 400]);
});

test('F6 a missing reference in the body is 422, a missing resource in the URL stays 404', async (t) => {
  const { get, write } = await setup(t);
  const bodyReference = [
    await write('POST', '/api/v1/inventaris', { id_jenis_inventaris: '999', nama_barang: 'x', satuan: 'g' }),
    await write('POST', '/api/v1/pemindahan', { id_penyemaian: '999', id_meja: '2', tanggal_pemindahan: '2026-10-01', jumlah_tanaman: 1 }),
    await write('POST', '/api/v1/pemindahan', { id_penyemaian: '1', id_meja: '999', tanggal_pemindahan: '2026-10-05', jumlah_tanaman: 1 }),
    await write('POST', '/api/v1/kerusakan', { id_pemindahan: '999', tanggal_kejadian: '2026-10-01', jumlah_tanaman: 1, jenis_kerusakan: 'x' }),
    await write('POST', '/api/v1/panen', { tanggal_panen: '2026-10-05', details: [{ id_pemindahan: '999', jumlah_tanaman: 1, berat_total: '1.00', berat_reject: '0.00' }] }),
  ];
  assert.deepEqual(bodyReference.map((response) => response.statusCode), [422, 422, 422, 422, 422]);
  assert.deepEqual(bodyReference.map(code), ['JENIS_NOT_FOUND', 'PENYEMAIAN_NOT_FOUND', 'TABLE_NOT_FOUND', 'TRANSFER_NOT_FOUND', 'TRANSFER_NOT_FOUND']);
  for (const url of ['/api/v1/penyemaian/999', '/api/v1/meja-tanam/999', '/api/v1/pemindahan/999', '/api/v1/kerusakan/999', '/api/v1/panen/999']) {
    assert.equal((await get(url)).statusCode, 404, url);
  }
});

// F7 / T-10: an open, unthrottled endpoint re-read every migration file on each call.
test('F7 readiness loads migration files once and still reports pending migrations', async (t) => {
  let loads = 0;
  const { app, db } = await setup(t, { loadMigrationFiles: async () => { loads += 1; return loadMigrations(); } });
  for (let i = 0; i < 5; i += 1) {
    assert.equal((await app.inject({ method: 'GET', url: '/health/ready' })).statusCode, 200);
  }
  assert.equal(loads, 1);
  await db.execute("DELETE FROM _schema_migrations WHERE id=(SELECT MAX(id) FROM _schema_migrations)");
  assert.equal((await app.inject({ method: 'GET', url: '/health/ready' })).statusCode, 503);
});

test('F7 a failed migration load is not cached', async (t) => {
  let loads = 0;
  const { app } = await setup(t, { loadMigrationFiles: async () => {
    loads += 1;
    if (loads === 1) throw new Error('disk busy');
    return loadMigrations();
  } });
  assert.equal((await app.inject({ method: 'GET', url: '/health/ready' })).statusCode, 503);
  assert.equal((await app.inject({ method: 'GET', url: '/health/ready' })).statusCode, 200);
});

// T-02: the login and refresh contract must survive the move from Ajv to Zod.
test('T-02 login and refresh keep their input contract', async (t) => {
  const { app } = await setup(t);
  const login = (payload) => app.inject({ method: 'POST', url: '/api/v1/auth/login', payload });
  const bad = [
    {}, { username: 'petani' }, { password: 'x' }, { username: '   ', password: 'x' }, { username: '', password: 'x' },
    { username: 'a'.repeat(51), password: 'x' }, { username: 'petani', password: '' },
    { username: 'petani', password: 'a'.repeat(129) }, { username: 'petani', password: 'x', extra: 1 },
    { username: 1, password: 'x' },
  ];
  for (const payload of bad) {
    const response = await login(payload);
    assert.equal(response.statusCode, 400, JSON.stringify(payload));
    assert.equal(code(response), 'VALIDATION_ERROR');
  }
  const noBody = await app.inject({ method: 'POST', url: '/api/v1/auth/login' });
  assert.equal(code(noBody), 'VALIDATION_ERROR');
  assert.equal(code(await login({ username: 'petani', password: 'salah' })), 'INVALID_CREDENTIALS');
  const refresh = (payload) => app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload });
  assert.equal(code(await refresh({ refresh_token: 'pendek' })), 'VALIDATION_ERROR');
  assert.equal(code(await refresh({ refresh_token: 'a'.repeat(43), extra: 1 })), 'VALIDATION_ERROR');
  assert.equal(code(await refresh({ refresh_token: 'a'.repeat(43) })), 'UNAUTHENTICATED');
});

// T-04: expired auth rows were only removed at boot. When it runs is pinned in session-sliding.test.js.
test('T-04 the purge removes only expired auth records', async (t) => {
  const { db } = await setup(t);
  await db.execute({ sql: `INSERT INTO auth_sessions(id_session,id_user,access_token_hash,refresh_token_hash,credential_hash,created_at,access_expires_at,refresh_expires_at)
    VALUES ('lama',1,'a1','r1','c',1,2,10),('baru',1,'a2','r2','c',1,2,1000)` });
  await db.execute("INSERT INTO auth_rate_limits(bucket_key,hits,resets_at) VALUES ('lama',1,10),('baru',1,1000)");
  await purgeExpiredAuthRecords(db, 500);
  const sessions = (await db.execute("SELECT id_session FROM auth_sessions WHERE id_session IN ('lama','baru')")).rows.map((row) => row.id_session);
  const limits = (await db.execute("SELECT bucket_key FROM auth_rate_limits WHERE bucket_key IN ('lama','baru')")).rows.map((row) => row.bucket_key);
  assert.deepEqual(sessions, ['baru']);
  assert.deepEqual(limits, ['baru']);
});

// T-11: the WIB offset was written out in six places, in three spellings.
test('T-11 jakartaDate turns over at midnight WIB, not midnight UTC', () => {
  assert.equal(jakartaDate(Date.parse('2026-10-07T16:59:59Z')), '2026-10-07');
  assert.equal(jakartaDate(Date.parse('2026-10-07T17:00:00Z')), '2026-10-08');
});
