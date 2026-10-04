import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { fixture, bearer } from './fixture.js';

export async function nurseryFixture(t) {
  const context = await fixture(t);
  const headers = bearer((await context.login('pegawai')).json().data.access_token);
  const reader = bearer((await context.login('petani')).json().data.access_token);

  // Setup inventory category and seed items
  const jenis = await context.app.inject({
    method: 'POST',
    url: '/api/v1/jenis-inventaris',
    headers,
    payload: { nama_jenis: 'Benih Tanaman' },
  });
  assert.equal(jenis.statusCode, 201, jenis.body);
  const id_jenis = jenis.json().data.id_jenis_inventaris;

  const items = [];
  for (const name of ['Benih Bayam Hijau', 'Benih Kangkung']) {
    const created = await context.app.inject({
      method: 'POST',
      url: '/api/v1/inventaris',
      headers,
      payload: { id_jenis_inventaris: id_jenis, nama_barang: name, satuan: 'gram', stok_minimum: '10' },
    });
    assert.equal(created.statusCode, 201, created.body);
    items.push(created.json().data);
  }

  // Stock incoming 500 grams for each seed item
  const stockIn = await context.app.inject({
    method: 'POST',
    url: '/api/v1/stok',
    headers: { ...headers, 'idempotency-key': randomUUID() },
    payload: {
      jenis_stok: 'masuk',
      keterangan: 'Initial seed stock',
      details: items.map((item) => ({ id_inventaris: item.id_inventaris, jumlah: '500', satuan: item.satuan })),
    },
  });
  assert.equal(stockIn.statusCode, 201, stockIn.body);

  /** Calculate YYYY-MM-DD in Asia/Jakarta (UTC+7) shifted by -days */
  const daysAgo = (days) => {
    const d = new Date(context.clock() + 7 * 3600 * 1000);
    d.setUTCDate(d.getUTCDate() - days);
    return d.toISOString().slice(0, 10);
  };

  const defaultPayload = (days = 0) => ({
    tanggal_semai: daysAgo(days),
    jumlah_benih: 100,
    keterangan: 'Penyemaian batch 1',
    materials: [{ id_inventaris: items[0].id_inventaris, jumlah: '5', satuan: items[0].satuan }],
  });

  const post = (payload = defaultPayload(), extraHeaders = {}) => context.app.inject({
    method: 'POST',
    url: '/api/v1/penyemaian',
    headers: { ...headers, 'idempotency-key': randomUUID(), ...extraHeaders },
    payload,
  });

  const patch = (id, payload, extraHeaders = {}) => context.app.inject({
    method: 'PATCH',
    url: `/api/v1/penyemaian/${id}`,
    headers: { ...headers, 'idempotency-key': randomUUID(), ...extraHeaders },
    payload,
  });

  const get = (id, extraHeaders = {}) => context.app.inject({
    method: 'GET',
    url: `/api/v1/penyemaian/${id}`,
    headers: { ...reader, ...extraHeaders },
  });

  const list = (query = '', extraHeaders = {}) => context.app.inject({
    method: 'GET',
    url: `/api/v1/penyemaian${query ? `?${query}` : ''}`,
    headers: { ...reader, ...extraHeaders },
  });

  return {
    ...context,
    headers,
    reader,
    items,
    daysAgo,
    defaultPayload,
    post,
    patch,
    get,
    list,
  };
}

export function expectError(response, status, code) {
  assert.equal(response.statusCode, status, response.body);
  assert.equal(response.json().error.code, code, response.body);
}
