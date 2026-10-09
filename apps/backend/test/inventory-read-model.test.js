import assert from 'node:assert/strict';
import { test } from 'node:test';
import { stockFixture } from '../test-support/stock-fixture.js';

test('inventory list and receipts expose exact balance without per-item reads', async (t) => {
  const { app, db, headers, reader, items, post, movement } = await stockFixture(t);
  assert.equal(items[0].saldo, '0');
  assert.equal(items[0].di_bawah_minimum, true);
  assert.equal(items[1].di_bawah_minimum, false);
  assert.equal((await post(movement('masuk', '0.1'))).statusCode, 201);
  for (const auth of [headers, reader]) {
    const list = await app.inject({ url: '/api/v1/inventaris?limit=1', headers: auth });
    assert.equal(list.statusCode, 200, list.body);
    assert.equal(list.json().meta.total_pages, 2);
    assert.equal(list.json().data[0].saldo, '0.1');
    assert.equal(list.json().data[0].di_bawah_minimum, false);
  }
  const id = items[0].id_inventaris;
  await db.execute({ sql: 'UPDATE stok_saldo SET saldo_minor=? WHERE id_inventaris=?',
    args: ['999999999999', id] });
  const detail = await app.inject({ url: `/api/v1/inventaris/${id}`, headers });
  assert.equal(detail.json().data.saldo, '9999999999.99');
  const patch = await app.inject({ method: 'PATCH', url: `/api/v1/inventaris/${id}`,
    headers, payload: { nama_barang: 'Updated' } });
  assert.equal(patch.statusCode, 200, patch.body);
  assert.equal(patch.json().data.saldo, '9999999999.99');
  const archive = await app.inject({ method: 'POST', url: `/api/v1/inventaris/${id}/deactivate`, headers });
  assert.equal(archive.json().data.saldo, '9999999999.99');
  const active = await app.inject({ url: '/api/v1/inventaris?status_aktif=1', headers });
  assert.equal(active.json().data.length, 1);
  assert.equal(active.json().data[0].saldo, '0');
});
