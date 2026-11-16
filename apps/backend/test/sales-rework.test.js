// Findings from reviewing features/sales after merging origin/main (2026-11-04).
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { bearer, fixture } from '../test-support/fixture.js';

async function setup(t) {
  const f = await fixture(t);
  const headers = bearer((await f.login('petani')).json().data.access_token);
  await f.db.executeMultiple(`
    INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih) VALUES(1,'2026-09-01',1000);
    INSERT INTO meja_tanam(kode_meja,jumlah_lubang) VALUES('M1',1000);
    INSERT INTO pemindahan(id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES(1,1,'2026-09-16',500);
  `);
  const harvest = await f.app.inject({ method: 'POST', url: '/api/v1/panen', headers, payload: {
    tanggal_panen: '2026-09-20', details: [{ id_pemindahan: '1', jumlah_tanaman: 5, berat_total: '90.00', berat_reject: '0.00' }] } });
  assert.equal(harvest.statusCode, 201, harvest.body);
  const sale = { tanggal_penjualan: '2026-09-25', pembeli: 'Toko', status_pembayaran: 'lunas', id_panen: '1', jumlah_kg: '1.50', harga_per_kg: '20000.00' };
  const send = (method, url, payload, extra = {}, options = {}) => f.app.inject({ method, url: `/api/v1/penjualan${url}`, payload, headers: { ...headers, ...extra }, ...options });
  return { ...f, headers, sale, send };
}

test('penjualan writes refuse a missing Idempotency-Key and write nothing', async (t) => {
  const { db, sale, send } = await setup(t);
  const created = await send('POST', '', sale, {}, { omitIdempotencyKey: true });
  assert.equal(created.statusCode, 400, created.body);
  assert.equal(Number((await db.execute('SELECT COUNT(*) AS n FROM penjualan')).rows[0].n), 0);
  assert.equal((await send('POST', '', sale)).statusCode, 201);
  const patched = await send('PATCH', '/1', { expected_version: '1', pembeli: 'Lain' }, {}, { omitIdempotencyKey: true });
  assert.equal(patched.statusCode, 400, patched.body);
  assert.equal((await db.execute('SELECT pembeli FROM penjualan WHERE id_penjualan=1')).rows[0].pembeli, 'Toko');
});

test('a harvest missing from the sale body is 422; a sale missing from the URL stays 404', async (t) => {
  const { sale, send } = await setup(t);
  const created = await send('POST', '', { ...sale, id_panen: '999' });
  assert.equal(created.statusCode, 422, created.body);
  assert.equal(created.json().error.code, 'HARVEST_NOT_FOUND');
  assert.equal((await send('POST', '', sale)).statusCode, 201);
  const moved = await send('PATCH', '/1', { expected_version: '1', id_panen: '999', jumlah_kg: '1.00', harga_per_kg: '1.00' });
  assert.equal(moved.statusCode, 422, moved.body);
  assert.equal((await send('GET', '/999')).statusCode, 404);
});

test('the sales list query count does not grow with rows and matches the detail shape', async (t) => {
  const { db, sale, send } = await setup(t);
  for (let i = 0; i < 30; i += 1) {
    const created = await send('POST', '', { ...sale, pembeli: `Toko ${i}`, jumlah_kg: '1.25' }, { 'idempotency-key': randomUUID() });
    assert.equal(created.statusCode, 201, created.body);
  }
  let queries = 0;
  const transaction = db.transaction.bind(db);
  db.transaction = async (mode) => {
    const tx = await transaction(mode);
    const execute = tx.execute.bind(tx);
    tx.execute = (...args) => { queries += 1; return execute(...args); };
    return tx;
  };
  const list = await send('GET', '?limit=30');
  db.transaction = transaction;
  assert.equal(list.statusCode, 200, list.body);
  const rows = list.json().data;
  assert.equal(rows.length, 30);
  assert.ok(queries <= 3, `expected at most 3 queries, ran ${queries}`);
  assert.equal(list.json().meta.total, 30);
  assert.equal(rows[0].pembeli, 'Toko 29');
  assert.equal(rows[29].pembeli, 'Toko 0');
  for (const row of [rows[0], rows[29]]) {
    assert.deepEqual(row, (await send('GET', `/${row.id_penjualan}`)).json().data);
    assert.equal(row.details[0].total_harga, '25000.00');
  }
  assert.deepEqual((await send('GET', '?page=9')).json().data, []);
});
