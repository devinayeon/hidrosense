import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { fixture, bearer } from './fixture.js';

export async function stockFixture(t) {
  const context = await fixture(t);
  const headers = bearer((await context.login('pegawai')).json().data.access_token);
  const reader = bearer((await context.login('petani')).json().data.access_token);
  const jenis = await context.app.inject({ method: 'POST', url: '/api/v1/jenis-inventaris',
    headers, payload: { nama_jenis: 'Stock fixture' } });
  assert.equal(jenis.statusCode, 201, jenis.body);
  const items = [];
  for (const name of ['A', 'B']) {
    const created = await context.app.inject({ method: 'POST', url: '/api/v1/inventaris', headers,
      payload: { id_jenis_inventaris: jenis.json().data.id_jenis_inventaris,
        nama_barang: name, satuan: 'kg', stok_minimum: name === 'A' ? '0.1' : null } });
    assert.equal(created.statusCode, 201, created.body);
    items.push(created.json().data);
  }
  const movement = (jenis_stok = 'masuk', jumlah = '1', item = items[0]) => ({
    jenis_stok, details: [{ id_inventaris: item.id_inventaris, jumlah, satuan: item.satuan }],
  });
  const post = (payload, extraHeaders = {}, url = '/api/v1/stok') => context.app.inject({
    method: 'POST', url, headers: { ...headers, 'idempotency-key': randomUUID(), ...extraHeaders }, payload,
  });
  const balance = async (item = items[0]) => {
    const response = await context.app.inject({ url: `/api/v1/inventaris/${item.id_inventaris}/saldo`, headers });
    assert.equal(response.statusCode, 200, response.body);
    return response.json().data;
  };
  return { ...context, headers, reader, items, movement, post, balance };
}

export function expectError(response, status, code) {
  assert.equal(response.statusCode, status, response.body);
  assert.equal(response.json().error.code, code, response.body);
}

export async function stockState(db) {
  const result = {};
  for (const table of ['stok', 'detail_stok', 'stok_saldo', 'sync_id_maps',
    'sync_resource_links', 'sync_resource_versions', 'sync_operations']) {
    result[table] = (await db.execute(`SELECT * FROM ${table} ORDER BY rowid`)).rows;
  }
  return result;
}
