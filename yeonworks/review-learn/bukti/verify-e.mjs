// My own check of slice-E claims E3, E4, E13. In-memory database only.
import { randomUUID } from 'node:crypto';
const src = 'file:///D:/Dev/Projects/hidrosense/apps/backend/src/';
const { buildApp } = await import(src + 'app.ts');
const { readConfig } = await import(src + 'config.ts');
const { openDatabase } = await import(src + 'db/client.ts');
const { loadMigrations, migrate } = await import(src + 'db/migrate.ts');
const { seed, SEED_CREDENTIALS } = await import(src + 'db/seed.ts');
const { jakartaDate } = await import(src + 'common/dates.ts');
const db = await openDatabase({ url: ':memory:' });
await migrate(db, await loadMigrations());
await seed(db);
const app = buildApp({ db, config: readConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent' }) });
await app.ready();
const token = (await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'petani', password: SEED_CREDENTIALS.petani.password } })).json().data.access_token;
const call = async (method, url, payload) => {
  const r = await app.inject({ method, url, payload, headers: { authorization: `Bearer ${token}`, 'idempotency-key': randomUUID() } });
  return { status: r.statusCode, json: r.body ? JSON.parse(r.body) : null };
};
const day = (n) => jakartaDate(Date.now() - n * 86400000);
const out = {};
const harvest = (await call('POST', '/api/v1/panen', { tanggal_panen: day(2), details: [{ id_pemindahan: '1', jumlah_tanaman: 5, berat_total: '10.00', berat_reject: '1.00' }] })).json.data;
const sale = (await call('POST', '/api/v1/penjualan', { tanggal_penjualan: day(1), pembeli: 'Toko', status_pembayaran: 'lunas', id_panen: harvest.id_panen, jumlah_kg: '2.00', harga_per_kg: '1000.00' })).json.data;
const cursor = (await call('GET', '/api/v1/sync/changes?limit=200')).json.meta.next_cursor;

// E3: edit the harvest weights, then see what the feed says and what the sale now shows
const before = (await call('GET', `/api/v1/penjualan/${sale.id_penjualan}`)).json.data;
const edit = await call('PATCH', `/api/v1/panen/${harvest.id_panen}`, { expected_version: harvest.version, details: [{ id_detail_panen: harvest.details[0].id_detail_panen, berat_total: '6.00', berat_reject: '1.00' }] });
const after = (await call('GET', `/api/v1/penjualan/${sale.id_penjualan}`)).json.data;
const feed = (await call('GET', `/api/v1/sync/changes?cursor=${cursor}`)).json.data.map((r) => r.resource_type);
out.E3 = { harvest_patch: edit.status, berat_layak_on_sale: [before.details[0].berat_layak, after.details[0].berat_layak], sale_version: [before.version, after.version], feed_types: feed };

// E4: same-value sale edit changes the detail id
const e4 = await call('PATCH', `/api/v1/penjualan/${sale.id_penjualan}`, { expected_version: after.version, id_panen: harvest.id_panen, jumlah_kg: '2.00', harga_per_kg: '1000.00' });
out.E4 = { patch: e4.status, detail_id: [after.details[0].id_detail_penjualan, e4.json.data?.details?.[0]?.id_detail_penjualan] };

// E13: unknown query parameter
const statuses = {};
for (const url of ['/api/v1/jenis-inventaris/1?junk=1', '/api/v1/employees/2?junk=1', '/api/v1/panen/1?junk=1', '/api/v1/penjualan/1?junk=1']) statuses[url.split('?')[0]] = (await call('GET', url)).status;
out.E13 = statuses;
console.log(JSON.stringify(out, null, 1));
await app.close();
