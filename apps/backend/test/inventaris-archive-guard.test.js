import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

// Regresi sesi 14: barang yang sudah diarsipkan hanya boleh dilihat dan
// diaktifkan kembali. Sebelum penjaga `assertInventarisActive`, PATCH dan
// deactivate ulang tetap diterima sehingga dua pegawai bisa membuat data
// berubah setelah arsip.

function pegawaiHeaders(login) {
  return login('pegawai').then((r) => bearer(r.json().data.access_token));
}

/** Satu barang aktif beserta headers pegawai. */
async function inventarisFixture(t) {
  const { app, login } = await fixture(t);
  const headers = await pegawaiHeaders(login);
  const jenis = (await app.inject({
    method: 'POST', url: '/api/v1/jenis-inventaris', headers, payload: { nama_jenis: 'Arsip Uji' },
  })).json().data;
  const created = await app.inject({
    method: 'POST', url: '/api/v1/inventaris', headers,
    payload: { id_jenis_inventaris: jenis.id_jenis_inventaris, nama_barang: 'Pupuk Uji', satuan: 'kg' },
  });
  assert.equal(created.statusCode, 201, created.body);
  const item = created.json().data;
  const url = `/api/v1/inventaris/${item.id_inventaris}`;
  return { app, headers, item, url };
}

test('PATCH on archived inventaris is refused and leaves the row untouched', async (t) => {
  const { app, headers, item, url } = await inventarisFixture(t);
  const archived = await app.inject({ method: 'POST', url: `${url}/deactivate`, headers });
  assert.equal(archived.statusCode, 200, archived.body);

  const patch = await app.inject({
    method: 'PATCH', url, headers, payload: { nama_barang: 'Pupuk Berubah', stok_minimum: '9' },
  });
  assert.equal(patch.statusCode, 409, patch.body);
  assert.equal(patch.json().error.code, 'INVENTARIS_ARCHIVED');

  const detail = await app.inject({ url, headers });
  assert.equal(detail.statusCode, 200, detail.body);
  assert.equal(detail.json().data.nama_barang, 'Pupuk Uji');
  assert.equal(detail.json().data.stok_minimum, null);
  assert.equal(detail.json().data.version, archived.json().data.version, item.version);
  assert.equal(detail.json().data.status_aktif, 0);
});

test('archived inventaris refuses a second deactivate but still allows activate', async (t) => {
  const { app, headers, url } = await inventarisFixture(t);
  assert.equal((await app.inject({ method: 'POST', url: `${url}/deactivate`, headers })).statusCode, 200);

  const again = await app.inject({ method: 'POST', url: `${url}/deactivate`, headers });
  assert.equal(again.statusCode, 409, again.body);
  assert.equal(again.json().error.code, 'INVENTARIS_ARCHIVED');

  const activated = await app.inject({ method: 'POST', url: `${url}/activate`, headers });
  assert.equal(activated.statusCode, 200, activated.body);
  assert.equal(activated.json().data.status_aktif, 1);
});

test('reactivating makes PATCH work again', async (t) => {
  const { app, headers, url } = await inventarisFixture(t);
  await app.inject({ method: 'POST', url: `${url}/deactivate`, headers });
  assert.equal((await app.inject({ method: 'PATCH', url, headers, payload: { nama_barang: 'Tolak' } })).statusCode, 409);

  await app.inject({ method: 'POST', url: `${url}/activate`, headers });
  const patch = await app.inject({ method: 'PATCH', url, headers, payload: { nama_barang: 'Setelah Pulih' } });
  assert.equal(patch.statusCode, 200, patch.body);
  assert.equal(patch.json().data.nama_barang, 'Setelah Pulih');
});

test('a retry with the same idempotency key replays, while a new key is refused', async (t) => {
  const { app, headers, url } = await inventarisFixture(t);
  const retryKey = randomUUID();
  const request = { method: 'POST', url: `${url}/deactivate`, headers: { ...headers, 'idempotency-key': retryKey } };

  const first = await app.inject(request);
  assert.equal(first.statusCode, 200, first.body);
  const replay = await app.inject(request);
  assert.equal(replay.statusCode, 200, replay.body);
  assert.deepEqual(replay.json().data, first.json().data);

  const newKey = await app.inject({
    method: 'POST', url: `${url}/deactivate`,
    headers: { ...headers, 'idempotency-key': randomUUID() },
  });
  assert.equal(newKey.statusCode, 409, newKey.body);
  assert.equal(newKey.json().error.code, 'INVENTARIS_ARCHIVED');
});

test('archiving wins over a later edit in the two-employee race', async (t) => {
  const { app, headers, item, url } = await inventarisFixture(t);
  // Karyawan A mengarsipkan lebih dulu; karyawan B baru menyimpan perubahan
  // dari layar yang masih menampilkan barang aktif.
  const [archived, edited] = [
    await app.inject({ method: 'POST', url: `${url}/deactivate`, headers }),
    await app.inject({ method: 'PATCH', url, headers, payload: { nama_barang: 'Dari B', stok_minimum: '3' } }),
  ];
  assert.equal(archived.statusCode, 200, archived.body);
  assert.equal(edited.statusCode, 409, edited.body);

  const detail = (await app.inject({ url, headers })).json().data;
  assert.equal(detail.nama_barang, 'Pupuk Uji', item.nama_barang);
  assert.equal(detail.stok_minimum, null);
  assert.equal(detail.status_aktif, 0);
});

test('archived inventaris still lists, reads its balance and its history', async (t) => {
  const { app, headers, url } = await inventarisFixture(t);
  await app.inject({ method: 'POST', url: `${url}/deactivate`, headers });

  assert.equal((await app.inject({ url, headers })).statusCode, 200);
  assert.equal((await app.inject({ url: `${url}/saldo`, headers })).statusCode, 200);
  const list = await app.inject({ url: '/api/v1/inventaris?status_aktif=0', headers });
  assert.equal(list.statusCode, 200, list.body);
  assert.ok(list.json().data.some((row) => row.id_inventaris === url.split('/').pop()));
});