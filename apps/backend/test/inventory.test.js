import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

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

test('jenis_inventaris deactivation preserves history and blocks new references', async (t) => {
  const { app, login } = await fixture(t);
  const headers = await pegawaiHeaders(login);
  const created = await app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris', headers, payload: { nama_jenis: 'Arsip' } });
  const jenis = created.json().data;
  const deactivated = await app.inject({ method: 'POST', url: `${created.headers.location}/deactivate`, headers });
  assert.equal(deactivated.statusCode, 200, deactivated.body);
  assert.equal(deactivated.json().data.status_aktif, 0);
  assert.equal((await app.inject({ url: `${created.headers.location}`, headers })).json().data.status_aktif, 0);
  const item = await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers, payload: {
    id_jenis_inventaris: jenis.id_jenis_inventaris, nama_barang: 'Ditolak', satuan: 'kg',
  } });
  assert.equal(item.statusCode, 422, item.body);
  const list = await app.inject({ url: '/api/v1/jenis-inventaris?status_aktif=0&limit=1&page=1', headers });
  assert.equal(list.json().meta.total, 1);
  assert.equal(list.json().data[0].id_jenis_inventaris, jenis.id_jenis_inventaris);
});

test('jenis_inventaris routes reject anonymous, allow petani write, reject bad IDs and extra fields', async (t) => {
  const { app, login } = await fixture(t);
  const petaniHdr = await petaniHeaders(login);
  const pegawaiHdr = await pegawaiHeaders(login);

  // anonymous
  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/jenis-inventaris' })).statusCode, 401);
  // petani can read and write
  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/jenis-inventaris', headers: petaniHdr })).statusCode, 200);
  const createdByPetani = await app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris', headers: petaniHdr, payload: jenisPayload });
  assert.equal(createdByPetani.statusCode, 201, createdByPetani.body);

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

test('obat routes reject anonymous, allow petani write, reject bad inputs', async (t) => {
  const { app, login } = await fixture(t);
  const petaniHdr = await petaniHeaders(login);
  const pegawaiHdr = await pegawaiHeaders(login);

  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/obat' })).statusCode, 401);
  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/obat', headers: petaniHdr })).statusCode, 200);
  const createdByPetani = await app.inject({ method: 'POST', url: '/api/v1/obat', headers: petaniHdr, payload: obatPayload });
  assert.equal(createdByPetani.statusCode, 201, createdByPetani.body);
  // not found
  assert.equal((await app.inject({ url: '/api/v1/obat/9999', headers: pegawaiHdr })).statusCode, 404);
  // bad payload
  assert.equal((await app.inject({ method: 'POST', url: '/api/v1/obat', headers: pegawaiHdr, payload: {} })).statusCode, 400);
  assert.equal((await app.inject({ method: 'PATCH', url: '/api/v1/obat/1', headers: pegawaiHdr, payload: {} })).statusCode, 400);
});

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
  assert.equal(item.stok_minimum, '10.5');
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

test('inventaris routes reject anonymous, allow petani write, reject bad inputs', async (t) => {
  const { app, login } = await fixture(t);
  const petaniHdr = await petaniHeaders(login);
  const pegawaiHdr = await pegawaiHeaders(login);

  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/inventaris' })).statusCode, 401);
  assert.equal((await app.inject({ method: 'GET', url: '/api/v1/inventaris', headers: petaniHdr })).statusCode, 200);

  const jenis = (await app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris', headers: petaniHdr, payload: jenisPayload })).json().data;
  const createdByPetani = await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers: petaniHdr, payload: { nama_barang: 'X', satuan: 'kg', id_jenis_inventaris: jenis.id_jenis_inventaris } });
  assert.equal(createdByPetani.statusCode, 201, createdByPetani.body);

  // not found
  assert.equal((await app.inject({ url: '/api/v1/inventaris/9999', headers: pegawaiHdr })).statusCode, 404);
  // empty update
  assert.equal((await app.inject({ method: 'PATCH', url: '/api/v1/inventaris/9999', headers: pegawaiHdr, payload: {} })).statusCode, 400);
});

test('inventaris writes replay atomically and reject reused keys with different payloads', async (t) => {
  const { app, login, db } = await fixture(t);
  const auth = await pegawaiHeaders(login);
  const jenis = (await app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris', headers: auth, payload: { nama_jenis: 'Replay' } })).json().data;
  const key = randomUUID();
  const headers = { ...auth, 'idempotency-key': key };
  const payload = { id_jenis_inventaris: jenis.id_jenis_inventaris, nama_barang: 'Sekop', satuan: 'unit', stok_minimum: '1.00' };
  const first = await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers, payload });
  const replay = await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers, payload });
  assert.equal(first.statusCode, 201, first.body);
  assert.equal(replay.statusCode, 200, replay.body);
  assert.deepEqual(replay.json().data, first.json().data);
  assert.equal(first.json().data.stok_minimum, '1');
  assert.equal((await db.execute("SELECT COUNT(*) AS n FROM inventaris WHERE nama_barang='Sekop'")).rows[0].n, 1);
  const conflict = await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers, payload: { ...payload, nama_barang: 'Cangkul' } });
  assert.equal(conflict.statusCode, 409, conflict.body);
});

test('inventory PATCH rejects empty jenis, unknown fields and null required fields without changing records', async (t) => {
  const { app, login } = await fixture(t);
  const headers = await pegawaiHeaders(login);
  const jenis = await app.inject({
    method: 'POST', url: '/api/v1/jenis-inventaris', headers, payload: jenisPayload,
  });
  assert.equal(jenis.statusCode, 201, jenis.body);
  const item = await app.inject({ method: 'POST', url: '/api/v1/inventaris', headers, payload: {
    id_jenis_inventaris: jenis.json().data.id_jenis_inventaris, nama_barang: 'Sekop', satuan: 'unit',
  } });
  assert.equal(item.statusCode, 201, item.body);

  for (const payload of [{}, { nama_jenis: 'Pupuk', extra: true }, { nama_jenis: null }]) {
    const response = await app.inject({ method: 'PATCH', url: jenis.headers.location, headers, payload });
    assert.equal(response.statusCode, 400, response.body);
  }
  for (const payload of [
    { extra: true }, { nama_barang: 'Berubah', extra: true },
    { id_jenis_inventaris: null }, { nama_barang: null }, { satuan: null },
  ]) {
    const response = await app.inject({ method: 'PATCH', url: item.headers.location, headers, payload });
    assert.equal(response.statusCode, 400, response.body);
  }
  assert.deepEqual((await app.inject({ url: jenis.headers.location, headers })).json().data, jenis.json().data);
  assert.deepEqual((await app.inject({ url: item.headers.location, headers })).json().data, item.json().data);
});
