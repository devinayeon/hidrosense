import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

function check(r, status, code) {
  assert.equal(r.statusCode, status, r.body);
  if (code) assert.equal(r.json().error.code, code, r.body);
}

async function setup(t, { twoHarvests = false } = {}) {
  const f = await fixture(t);
  const pegawaiHeaders = bearer((await f.login('pegawai')).json().data.access_token);
  await f.db.executeMultiple(`
    INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih) VALUES(2,'2026-09-01',1000);
    INSERT INTO meja_tanam(kode_meja,jumlah_lubang) VALUES('M1',1000);
    INSERT INTO pemindahan(id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES
      (1,1,'2026-09-16',200),(1,1,'2026-09-16',200);
  `);

  async function harvest(transferId, total = '2.00', reject = '0.20') {
    const response = await f.app.inject({
      method: 'POST',
      url: '/api/v1/panen',
      headers: pegawaiHeaders,
      payload: {
        tanggal_panen: '2026-09-20',
        keterangan: 'panen',
        details: [{ id_pemindahan: transferId, jumlah_tanaman: 5, berat_total: total, berat_reject: reject }],
      },
    });
    check(response, 201);
    return response.json().data;
  }

  const harvestOne = await harvest('1');
  if (twoHarvests) await harvest('2');
  const petaniHeaders = bearer((await f.login('petani')).json().data.access_token);
  const send = (method, path = '', body, extra = {}) => f.app.inject({
    method,
    url: '/api/v1/penjualan' + path,
    payload: body,
    headers: { ...petaniHeaders, ...extra },
  });
  const post = (body, extra = {}) => send('POST', '', body, extra);
  const body = (overrides = {}) => ({
    tanggal_penjualan: '2026-09-25',
    pembeli: 'Supermarket Jaya',
    status_pembayaran: 'lunas',
    keterangan: ' catatan ',
    id_panen: '1',
    jumlah_kg: '1.00',
    harga_per_kg: '20000.00',
    ...overrides,
  });

  return { ...f, pegawaiHeaders, petaniHeaders, harvestOne, send, post, body };
}

test('sales create persists, replays, paginates, and enforces permissions', async (t) => {
  const f = await setup(t);
  const key = randomUUID(), client = randomUUID();
  const body = f.body();
  const created = await f.post(body, { 'idempotency-key': key, 'x-client-id': client });
  check(created, 201);
  const sale = created.json().data;
  assert.equal(sale.id_penjualan, '1');
  assert.equal(sale.id_user, '1');
  assert.equal(sale.tanggal_penjualan, '2026-09-25');
  assert.equal(sale.pembeli, 'Supermarket Jaya');
  assert.equal(sale.status_pembayaran, 'lunas');
  assert.equal(sale.keterangan, 'catatan');
  assert.equal(sale.version, '1');
  assert.ok(sale.public_id);
  assert.equal(sale.details.length, 1);
  assert.equal(sale.details[0].id_panen, '1');
  assert.equal(sale.details[0].jumlah_kg, '1.00');
  assert.equal(sale.details[0].harga_per_kg, '20000.00');
  assert.equal(sale.details[0].total_harga, '20000.00');
  assert.equal(sale.details[0].berat_layak, '1.80');

  const replay = await f.post(body, { 'idempotency-key': key, 'x-client-id': client });
  check(replay, 200);
  assert.equal(replay.json().replayed, true);
  assert.deepEqual(replay.json().data, sale);
  check(await f.post({ ...body, jumlah_kg: '0.50' }, { 'idempotency-key': key, 'x-client-id': client }), 409, 'OPERATION_CONFLICT');

  const second = await f.post(f.body({ tanggal_penjualan: '2026-09-26', pembeli: 'Toko B', jumlah_kg: '0.50' }));
  check(second, 201);
  const one = await f.send('GET', '?page=1&limit=1');
  check(one, 200);
  assert.equal(one.json().meta.total, 2);
  assert.equal(one.json().meta.total_pages, 2);
  assert.equal(one.json().data[0].id_penjualan, '2');
  const two = await f.send('GET', '?page=2&limit=1');
  check(two, 200);
  assert.equal(two.json().data[0].id_penjualan, '1');
  const got = await f.send('GET', '/1');
  check(got, 200);
  assert.deepEqual(got.json().data, sale);

  check(await f.app.inject({ url: '/api/v1/penjualan', headers: f.pegawaiHeaders }), 403);
  check(await f.app.inject({ method: 'POST', url: '/api/v1/penjualan', headers: f.pegawaiHeaders, payload: body }), 403);
  check(await f.app.inject({ url: '/api/v1/penjualan' }), 401);
  for (const limit of ['101', '0', '1.5', '999999999999']) check(await f.send('GET', '?limit=' + limit), 400);
});

test('sales stock is cumulative and an edit excludes its own old quantity', async (t) => {
  const f = await setup(t, { twoHarvests: true });
  check(await f.post(f.body()), 201);
  check(await f.post(f.body({ jumlah_kg: '0.80' })), 201);
  check(await f.post(f.body({ jumlah_kg: '0.01' })), 409, 'SALE_EXCEEDS_HARVEST_STOCK');

  const same = await f.send('PATCH', '/1', {
    expected_version: '1', id_panen: '1', jumlah_kg: '1.00', harga_per_kg: '21000.00',
  });
  check(same, 200);
  check(await f.send('PATCH', '/1', {
    expected_version: '2', id_panen: '1', jumlah_kg: '1.80', harga_per_kg: '21000.00',
  }), 409, 'SALE_EXCEEDS_HARVEST_STOCK');

  const moved = await f.send('PATCH', '/1', {
    expected_version: '2', id_panen: '2', jumlah_kg: '0.90', harga_per_kg: '21000.00',
  });
  check(moved, 200);
  assert.equal(moved.json().data.details[0].id_panen, '2');
  assert.equal(moved.json().data.details[0].jumlah_kg, '0.90');
  check(await f.post(f.body({ id_panen: '1', jumlah_kg: '1.00' })), 201);
  check(await f.post(f.body({ id_panen: '1', jumlah_kg: '0.01' })), 409, 'SALE_EXCEEDS_HARVEST_STOCK');
});

test('legacy decimal sales reduce stock and ambiguous values fail safely', async (t) => {
  const f = await setup(t);
  await f.db.executeMultiple(`
    INSERT INTO penjualan(id_user,tanggal_penjualan) VALUES(1,'2026-09-25');
    INSERT INTO detail_penjualan(id_penjualan,id_panen,jumlah_kg,harga_per_kg) VALUES(1,1,1.00,20000);
  `);
  check(await f.post(f.body({ jumlah_kg: '0.81' })), 409, 'SALE_EXCEEDS_HARVEST_STOCK');
  check(await f.post(f.body({ jumlah_kg: '0.80' })), 201);

  const ambiguous = await setup(t);
  await ambiguous.db.executeMultiple(`
    INSERT INTO penjualan(id_user,tanggal_penjualan) VALUES(1,'2026-09-25');
    INSERT INTO detail_penjualan(id_penjualan,id_panen,jumlah_kg,harga_per_kg) VALUES(1,1,0.30000000000000004,20000);
  `);
  check(await ambiguous.post(ambiguous.body({ jumlah_kg: '1.00' })), 409, 'SALE_LEGACY_AMOUNT_INVALID');
});

test('sales update enforces conflict, date, partial fields, and replay', async (t) => {
  const f = await setup(t);
  check(await f.post(f.body()), 201);
  const patch = (body, extra = {}) => f.send('PATCH', '/1', body, extra);
  check(await patch({ expected_version: '1' }), 400);
  check(await patch({ expected_version: '1', jumlah_kg: '0.50' }), 400);
  check(await patch({ expected_version: '1', id_panen: '1', jumlah_kg: '0.50', harga_per_kg: '20000.00' }), 200);
  check(await patch({ expected_version: '1', pembeli: 'Lama' }), 409, 'SALE_VERSION_CONFLICT');

  const header = await patch({ expected_version: '2', pembeli: 'Pembeli Baru', status_pembayaran: 'belum_lunas', keterangan: null });
  check(header, 200);
  assert.equal(header.json().data.version, '3');
  assert.equal(header.json().data.details[0].jumlah_kg, '0.50');
  assert.equal(header.json().data.keterangan, null);

  const key = randomUUID();
  const replayBody = { expected_version: '3', tanggal_penjualan: '2026-09-26' };
  const first = await patch(replayBody, { 'idempotency-key': key });
  check(first, 200);
  assert.equal(first.json().data.version, '4');
  const replay = await patch(replayBody, { 'idempotency-key': key });
  check(replay, 200);
  assert.equal(replay.json().replayed, true);
  assert.equal(replay.json().data.version, '4');

  check(await patch({ expected_version: '4', tanggal_penjualan: '2026-09-19' }), 400, 'INVALID_SALE_DATE');
  check(await patch({ expected_version: '4', tanggal_penjualan: '2026-10-01' }), 400, 'VALIDATION_ERROR');
  check(await patch({ expected_version: 4, pembeli: 'X' }), 400);
  check(await f.send('PATCH', '/999', { expected_version: '1', pembeli: 'X' }), 404, 'SALE_NOT_FOUND');
});

test('sales rejects invalid payloads and unknown harvests', async (t) => {
  const f = await setup(t);
  const invalid = [
    f.body({ tanggal_penjualan: '2026-02-30' }),
    f.body({ tanggal_penjualan: '2026-10-01' }),
    f.body({ tanggal_penjualan: '2026-09-19' }),
    f.body({ pembeli: '   ' }),
    f.body({ pembeli: 'x'.repeat(101) }),
    f.body({ status_pembayaran: 'paid' }),
    f.body({ keterangan: 'x'.repeat(1001) }),
    f.body({ id_panen: '0' }),
    f.body({ jumlah_kg: '0.00' }),
    f.body({ jumlah_kg: '-1' }),
    f.body({ jumlah_kg: '1.001' }),
    f.body({ jumlah_kg: '100000000.00' }),
    f.body({ harga_per_kg: '0' }),
    f.body({ harga_per_kg: '1.001' }),
    f.body({ harga_per_kg: '10000000000.00' }),
    { ...f.body(), extra: true },
    { ...f.body(), id_panen: undefined },
  ];
  for (const body of invalid) check(await f.post(body), 400);
  check(await f.post(f.body({ id_panen: '999' })), 404, 'HARVEST_NOT_FOUND');
  check(await f.post(f.body({ id_panen: '1', jumlah_kg: '1.80', harga_per_kg: '9999999999.99' })), 201);
});

test('sale detail failure rolls back header, receipt, and identity; retry succeeds', async (t) => {
  const f = await setup(t);
  await f.db.execute("CREATE TRIGGER reject_sale_detail BEFORE INSERT ON detail_penjualan BEGIN SELECT RAISE(ABORT,'test failure'); END");
  const headers = { 'idempotency-key': randomUUID(), 'x-client-id': randomUUID() };
  check(await f.post(f.body(), headers), 500);
  for (const [table, where] of [
    ['penjualan', ''],
    ['detail_penjualan', ''],
    ['sync_operations', " WHERE operation_type LIKE 'penjualan.%'"],
    ['sync_resource_versions', " WHERE resource_type = 'penjualan'"],
    ['sync_resource_links', " WHERE resource_type = 'penjualan'"],
    ['sync_id_maps', " WHERE resource_type = 'penjualan'"],
  ]) {
    assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM ' + table + where)).rows[0].n, 0, table);
  }
  await f.db.execute('DROP TRIGGER reject_sale_detail');
  check(await f.post(f.body(), headers), 201);
});
