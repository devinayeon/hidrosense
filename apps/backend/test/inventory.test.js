import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

// ── helpers ──────────────────────────────────────────────────────────────────

function petaniHeaders(login) {
  return login().then((r) => bearer(r.json().data.access_token));
}
function pegawaiHeaders(login) {
  return login('pegawai').then((r) => bearer(r.json().data.access_token));
}

const jenisPayload = { nama_jenis: 'Nutrisi' };
const obatPayload = {
  nama_obat: 'Fungisida A', jenis_obat: 'Fungisida',
  dosis: '2ml/L', aturan_penggunaan: 'Semprotkan', deskripsi: 'Untuk jamur',
};

// ── jenis_inventaris ─────────────────────────────────────────────────────────

test('pegawai creates, lists, reads and updates jenis_inventaris', async (t) => {
  const { app, login } = await fixture(t);
  const headers = await pegawaiHeaders(login);

  const created = await app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris', headers, payload: jenisPayload });
  assert.equal(created.statusCode, 201, created.body);
  const jenis = created.json().data;
  assert.equal(jenis.nama_jenis, 'Nutrisi');
  assert.equal(typeof jenis.id_jenis_inventaris, 'string');
  assert.equal(created.headers.location, `/api/v1/jenis-inventaris/${jenis.id_jenis_inventaris}`);

  const detail = await app.inject({ url: created.headers.location, headers });
  assert.deepEqual(detail.json().data, jenis);

  const list = await app.inject({ url: '/api/v1/jenis-inventaris', headers });
  assert.equal(list.statusCode, 200, list.body);
  assert.ok(list.json().data.some((j) => j.id_jenis_inventaris === jenis.id_jenis_inventaris));

  const updated = await app.inject({
    method: 'PATCH', url: created.headers.location, headers,
    payload: { nama_jenis: 'Pupuk' },
  });
  assert.equal(updated.statusCode, 200, updated.body);
  assert.equal(updated.json().data.nama_jenis, 'Pupuk');
});

test('jenis_inventaris enforces unique name', async (t) => {
  const { app, login } = await fixture(t);
  const headers = await pegawaiHeaders(login);
  await app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris', headers, payload: { nama_jenis: 'Duplikat' } });
  const dup = await app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris', headers, payload: { nama_jenis: 'Duplikat' } });
  assert.equal(dup.statusCode, 409);
  assert.equal(dup.json().error.code, 'JENIS_NAME_TAKEN');
});

test('jenis_inventaris routes reject anonymous, petani write, bad IDs and extra fields', async (t) => {
  const { app, login } = await fixture(t);
  const petaniHdr = await petaniHeaders(login);
  const pegawaiHdr = await pegawaiHeaders(login);

  // anonymous
  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/jenis-inventaris' })).statusCode, 401);
  // petani can read but not write
  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/jenis-inventaris', headers: petaniHdr })).statusCode, 200);
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris', headers: petaniHdr, payload: jenisPayload })).statusCode, 403);

  // bad IDs
  for (const id of ['0', 'abc', '-1', '9223372036854775808']) {
    assert.equal((await app.inject({ url: `/api/v1/jenis-inventaris/${id}`, headers: pegawaiHdr })).statusCode, 400);
  }
  // extra fields
  assert.equal((await app.inject({
    method: 'POST', url: '/api/v1/jenis-inventaris', headers: pegawaiHdr,
    payload: { nama_jenis: 'X', extra: true },
  })).statusCode, 400);
});

// ── obat ─────────────────────────────────────────────────────────────────────

test('pegawai creates, lists, reads, updates and deactivates obat', async (t) => {
  const { app, login } = await fixture(t);
  const headers = await pegawaiHeaders(login);

  const created = await app.inject({ method: 'POST', url: '/api/v1/obat', headers, payload: obatPayload });
  assert.equal(created.statusCode, 201, created.body);
  const obat = created.json().data;
  assert.equal(obat.nama_obat, 'Fungisida A');
  assert.equal(obat.status_aktif, 1);
  assert.doesNotMatch(created.body, /password/);

  const detail = await app.inject({ url: created.headers.location, headers });
  assert.deepEqual(detail.json().data, obat);

  const list = await app.inject({ url: '/api/v1/obat', headers });
  assert.equal(list.statusCode, 200, list.body);
  assert.ok(list.json().data.some((o) => o.id_obat === obat.id_obat));

  const updated = await app.inject({
    method: 'PATCH', url: created.headers.location, headers,
    payload: { nama_obat: 'Fungisida B', jenis_obat: null },
  });
  assert.equal(updated.statusCode, 200, updated.body);
  assert.equal(updated.json().data.nama_obat, 'Fungisida B');
  assert.equal(updated.json().data.jenis_obat, null);

  const deactivated = await app.inject({ method: 'POST', url: `${created.headers.location}/deactivate`, headers });
  assert.equal(deactivated.statusCode, 200, deactivated.body);
  assert.equal(deactivated.json().data.status_aktif, 0);

  // deactivated obat still visible in detail (history preserved)
  assert.equal((await app.inject({ url: created.headers.location, headers })).statusCode, 200);
});

test('obat list pagination and status_aktif filter work correctly', async (t) => {
  const { app, login } = await fixture(t);
  const headers = await pegawaiHeaders(login);
  await app.inject({ method: 'POST', url: '/api/v1/obat', headers, payload: { nama_obat: 'A' } });
  await app.inject({ method: 'POST', url: '/api/v1/obat', headers, payload: { nama_obat: 'B' } });

  const all = await app.inject({ url: '/api/v1/obat?limit=1&page=1', headers });
  assert.equal(all.json().meta.total, 2);
  assert.equal(all.json().meta.total_pages, 2);
  assert.equal(all.json().data.length, 1);

  const aktif = await app.inject({ url: '/api/v1/obat?status_aktif=1', headers });
  assert.ok(aktif.json().data.every((o) => o.status_aktif === 1));
});

test('obat routes reject anonymous, petani write, bad inputs', async (t) => {
  const { app, login } = await fixture(t);
  const petaniHdr = await petaniHeaders(login);
  const pegawaiHdr = await pegawaiHeaders(login);

  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/obat' })).statusCode, 401);
  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/obat', headers: petaniHdr })).statusCode, 200);
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/obat', headers: petaniHdr, payload: { nama_obat: 'X' } })).statusCode, 403);
  // not found
  assert.equal((await app.inject({ url: '/api/v1/obat/9999', headers: pegawaiHdr })).statusCode, 404);
  // bad payload
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/obat', headers: pegawaiHdr, payload: {} })).statusCode, 400);
  assert.equal((await app.inject({ method: 'PATCH', url: '/api/v1/obat/1', headers: pegawaiHdr, payload: {} })).statusCode, 400);
});

// ── inventaris ───────────────────────────────────────────────────────────────

test('pegawai creates, lists, reads, updates and deactivates inventaris', async (t) => {
  const { app, login, db } = await fixture(t);
  const headers = await pegawaiHeaders(login);

  // Seed prerequisite jenis
  const jenis = (await app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris', headers, payload: { nama_jenis: 'Kimia' } })).json().data;
  const obat = (await app.inject({ method: 'POST', url: '/api/v1/obat', headers, payload: { nama_obat: 'Obat X' } })).json().data;

  const payload = {
    id_jenis_inventaris: jenis.id_jenis_inventaris,
    id_obat: obat.id_obat,
    nama_barang: 'Pupuk A',
    satuan: 'kg',
    stok_minimum: '10.50',
  };
  const created = await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers, payload });
  assert.equal(created.statusCode, 201, created.body);
  const item = created.json().data;
  assert.equal(item.nama_barang, 'Pupuk A');
  assert.equal(item.satuan, 'kg');
  assert.equal(item.stok_minimum, 10.5);
  assert.equal(item.status_aktif, 1);
  assert.equal(item.nama_jenis, 'Kimia');
  assert.equal(item.nama_obat, 'Obat X');
  assert.equal(created.headers.location, `/api/v1/inventaris/${item.id_inventaris}`);

  const detail = await app.inject({ url: created.headers.location, headers });
  assert.deepEqual(detail.json().data, item);

  const list = await app.inject({ url: '/api/v1/inventaris', headers });
  assert.equal(list.statusCode, 200, list.body);
  assert.ok(list.json().data.some((i) => i.id_inventaris === item.id_inventaris));

  const updated = await app.inject({
    method: 'PATCH', url: created.headers.location, headers,
    payload: { nama_barang: 'Pupuk B', stok_minimum: null, id_obat: null },
  });
  assert.equal(updated.statusCode, 200, updated.body);
  assert.equal(updated.json().data.nama_barang, 'Pupuk B');
  assert.equal(updated.json().data.stok_minimum, null);
  assert.equal(updated.json().data.id_obat, null);

  const deactivated = await app.inject({ method: 'POST', url: `${created.headers.location}/deactivate`, headers });
  assert.equal(deactivated.statusCode, 200, deactivated.body);
  assert.equal(deactivated.json().data.status_aktif, 0);

  // inactive item still readable (history preserved)
  assert.equal((await app.inject({ url: created.headers.location, headers })).statusCode, 200);

  void db;
});

test('inventaris rejects invalid jenis and inactive obat references', async (t) => {
  const { app, login } = await fixture(t);
  const headers = await pegawaiHeaders(login);

  const jenis = (await app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris', headers, payload: { nama_jenis: 'Cat' } })).json().data;
  const obat = (await app.inject({ method: 'POST', url: '/api/v1/obat', headers, payload: { nama_obat: 'Obat Y' } })).json().data;
  await app.inject({ method: 'POST', url: `/api/v1/obat/${obat.id_obat}/deactivate`, headers });

  // nonexistent jenis
  const r1 = await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers, payload: {
    id_jenis_inventaris: '9999', nama_barang: 'X', satuan: 'kg',
  } });
  assert.equal(r1.statusCode, 422);

  // inactive obat
  const r2 = await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers, payload: {
    id_jenis_inventaris: jenis.id_jenis_inventaris, id_obat: obat.id_obat, nama_barang: 'X', satuan: 'kg',
  } });
  assert.equal(r2.statusCode, 422);
});

test('inventaris routes reject anonymous, petani write, bad inputs', async (t) => {
  const { app, login } = await fixture(t);
  const petaniHdr = await petaniHeaders(login);
  const pegawaiHdr = await pegawaiHeaders(login);

  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/inventaris' })).statusCode, 401);
  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/inventaris', headers: petaniHdr })).statusCode, 200);
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers: petaniHdr, payload: { nama_barang: 'X', satuan: 'kg', id_jenis_inventaris: '1' } })).statusCode, 403);
  // not found
  assert.equal((await app.inject({ url: '/api/v1/inventaris/9999', headers: pegawaiHdr })).statusCode, 404);
  // empty update
  assert.equal((await app.inject({ method: 'PATCH', url: '/api/v1/inventaris/9999', headers: pegawaiHdr, payload: {} })).statusCode, 400);
});
