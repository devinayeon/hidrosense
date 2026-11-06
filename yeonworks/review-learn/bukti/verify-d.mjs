// My own check of slice-D claims D1, D2, D5. In-memory database only.
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
const login = (await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'petani', password: SEED_CREDENTIALS.petani.password } })).json().data.access_token;
const call = async (method, url, payload) => {
  const r = await app.inject({ method, url, payload, headers: { authorization: `Bearer ${login}`, 'idempotency-key': randomUUID() } });
  return { status: r.statusCode, json: r.body ? JSON.parse(r.body) : null };
};
const old = jakartaDate(Date.now() - 40 * 86400000);
const moved = jakartaDate(Date.now() - 20 * 86400000);
const mat = [{ id_inventaris: '1', jumlah: '1', satuan: 'gram' }];
const out = {};

// D1: sowing of 50, move all 50, then try to correct the count
const s1 = (await call('POST', '/api/v1/penyemaian', { tanggal_semai: old, jumlah_benih: 50, materials: mat })).json.data;
const t1 = await call('POST', '/api/v1/pemindahan', { id_penyemaian: s1.id_penyemaian, id_meja: '2', tanggal_pemindahan: moved, jumlah_tanaman: 50 });
const done = (await call('GET', `/api/v1/penyemaian/${s1.id_penyemaian}`)).json.data;
out.D1 = { transfer: t1.status, status_after: done.status_penyemaian, sisa: done.sisa_benih, siap_pindah: done.siap_pindah, version: done.version,
  patch_count: (await call('PATCH', `/api/v1/penyemaian/${s1.id_penyemaian}`, { jumlah_benih: 80 })).json.error?.code,
  patch_note: (await call('PATCH', `/api/v1/penyemaian/${s1.id_penyemaian}`, { keterangan: 'x' })).json.error?.code };

// D2: sowing of 100, move 60, shrink to 60
const s2 = (await call('POST', '/api/v1/penyemaian', { tanggal_semai: old, jumlah_benih: 100, materials: mat })).json.data;
await call('POST', '/api/v1/pemindahan', { id_penyemaian: s2.id_penyemaian, id_meja: '3', tanggal_pemindahan: moved, jumlah_tanaman: 60 });
const shrink = await call('PATCH', `/api/v1/penyemaian/${s2.id_penyemaian}`, { jumlah_benih: 60 });
const stuck = (await call('GET', `/api/v1/penyemaian/${s2.id_penyemaian}`)).json.data;
const more = await call('POST', '/api/v1/pemindahan', { id_penyemaian: s2.id_penyemaian, id_meja: '3', tanggal_pemindahan: moved, jumlah_tanaman: 1 });
out.D2 = { shrink: shrink.status, status: stuck.status_penyemaian, sisa: stuck.sisa_benih, siap_pindah: stuck.siap_pindah, next_transfer: [more.status, more.json.error?.code] };

// D5: a table that is exactly full versus one that is short of holes
const s3 = (await call('POST', '/api/v1/penyemaian', { tanggal_semai: old, jumlah_benih: 400, materials: mat })).json.data;
const tbl = (await call('POST', '/api/v1/meja-tanam', { kode_meja: 'UJI-5', jumlah_lubang: 5 })).json.data;
await call('POST', '/api/v1/pemindahan', { id_penyemaian: s3.id_penyemaian, id_meja: tbl.id_meja, tanggal_pemindahan: moved, jumlah_tanaman: 4 });
const short = await call('POST', '/api/v1/pemindahan', { id_penyemaian: s3.id_penyemaian, id_meja: tbl.id_meja, tanggal_pemindahan: moved, jumlah_tanaman: 2 });
await call('POST', '/api/v1/pemindahan', { id_penyemaian: s3.id_penyemaian, id_meja: tbl.id_meja, tanggal_pemindahan: moved, jumlah_tanaman: 1 });
const full = await call('POST', '/api/v1/pemindahan', { id_penyemaian: s3.id_penyemaian, id_meja: tbl.id_meja, tanggal_pemindahan: moved, jumlah_tanaman: 1 });
out.D5 = { short_of_holes: short.json.error?.code, exactly_full: full.json.error?.code, message: full.json.error?.message };
console.log(JSON.stringify(out, null, 1));
await app.close();
