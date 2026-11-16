// My own check of two slice-C claims. In-memory database only.
import { randomUUID } from 'node:crypto';
const src = 'file:///D:/Dev/Projects/hidrosense/apps/backend/src/';
const { buildApp } = await import(src + 'app.ts');
const { readConfig } = await import(src + 'config.ts');
const { openDatabase } = await import(src + 'db/client.ts');
const { loadMigrations, migrate } = await import(src + 'db/migrate.ts');
const { seed, SEED_CREDENTIALS } = await import(src + 'db/seed.ts');
const db = await openDatabase({ url: ':memory:' });
await migrate(db, await loadMigrations());
await seed(db);
const app = buildApp({ db, config: readConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent' }) });
await app.ready();
const call = async (method, url, token, payload, extra = {}) => {
  const r = await app.inject({ method, url, payload, headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), 'idempotency-key': randomUUID(), ...extra } });
  return { status: r.statusCode, json: r.body ? JSON.parse(r.body) : null };
};
const login = async (u, p) => (await call('POST', '/api/v1/auth/login', null, { username: u, password: p })).json.data.access_token;
const out = {};
const petani = await login('petani', SEED_CREDENTIALS.petani.password);

// C3: a PATCH that writes the same value
const before = (await call('GET', '/api/v1/inventaris/1', petani)).json.data;
const same = await call('PATCH', '/api/v1/inventaris/1', petani, { nama_barang: before.nama_barang });
out.C3_same_value_patch = { status: same.status, version_before: before.version, version_after: same.json.data.version };
const stale = await call('PATCH', '/api/v1/inventaris/1', petani, { nama_barang: 'Lain', expected_version: before.version });
out.C3_other_device_with_old_version = { status: stale.status, code: stale.json?.error?.code };

// C5: PATCH an employee with the username it already has
const pegawai = await login('pegawai', SEED_CREDENTIALS.pegawai.password);
const patched = await call('PATCH', '/api/v1/employees/2', petani, { username: 'pegawai' });
const me = await call('GET', '/api/v1/auth/me', pegawai);
out.C5_same_username = { patch: patched.status, pegawai_token_after: me.status };
console.log(JSON.stringify(out, null, 1));
await app.close();
