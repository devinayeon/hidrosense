import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { nurseryFixture, expectError } from '../test-support/nursery-fixture.js';

test('N-01: Create sowing records stock consumption atomically with domain receipt', async (t) => {
  const f = await nurseryFixture(t);
  const payload = f.defaultPayload(2);
  const res = await f.post(payload);
  assert.equal(res.statusCode, 201, res.body);

  const { data, operation } = res.json();
  assert.equal(typeof data.id_penyemaian, 'string');
  assert.equal(typeof data.public_id, 'string');
  assert.match(data.public_id, /^[a-f0-9-]{36}$/);
  assert.equal(data.version, '1');
  assert.equal(data.id_user, '2'); // pegawai
  assert.equal(data.tanggal_semai, payload.tanggal_semai);
  assert.equal(data.jumlah_benih, 100);
  assert.equal(data.status_penyemaian, 'aktif');
  assert.equal(data.keterangan, 'Penyemaian batch 1');
  assert.equal(data.usia_hari, 2);
  assert.equal(data.siap_pindah, false);

  assert.equal(operation.public_id, data.public_id);
  assert.equal(operation.version, '1');

  // Verify stock deduction
  const saldoRes = await f.app.inject({
    url: `/api/v1/inventaris/${f.items[0].id_inventaris}/saldo`,
    headers: f.headers,
  });
  assert.equal(saldoRes.statusCode, 200);
  assert.equal(saldoRes.json().data.saldo, '495'); // 500 - 5 = 495

  // Verify stock movement ledger link
  const stockMovements = (await f.db.execute({
    sql: 'SELECT id_stok, jenis_stok, id_penyemaian, sealed FROM stok WHERE id_penyemaian=?',
    args: [data.id_penyemaian],
  })).rows;
  assert.equal(stockMovements.length, 1);
  assert.equal(stockMovements[0].jenis_stok, 'keluar');
  assert.equal(stockMovements[0].sealed, 1);
});

test('N-02 & N-03: Idempotency replay returns 200 while key reuse with changed payload returns 409', async (t) => {
  const f = await nurseryFixture(t);
  const key = randomUUID();
  const payload = f.defaultPayload();

  const first = await f.post(payload, { 'idempotency-key': key });
  assert.equal(first.statusCode, 201, first.body);
  assert.equal(first.json().replayed, false);

  // Replay exact same request
  const replay = await f.post(payload, { 'idempotency-key': key });
  assert.equal(replay.statusCode, 200, replay.body);
  assert.equal(replay.json().replayed, true);
  assert.deepEqual(replay.json().data, first.json().data);

  // Stock deduction must not happen twice
  const saldoRes = await f.app.inject({
    url: `/api/v1/inventaris/${f.items[0].id_inventaris}/saldo`,
    headers: f.headers,
  });
  assert.equal(saldoRes.json().data.saldo, '495');

  // Conflict key with different payload
  const conflict = await f.post({ ...payload, jumlah_benih: 999 }, { 'idempotency-key': key });
  expectError(conflict, 409, 'OPERATION_CONFLICT');
});

test('N-04: List filtering by status_penyemaian and siap_pindah (age >= 15 days)', async (t) => {
  const f = await nurseryFixture(t);

  // Create 3 sowings:
  // 1: age 20 days -> ready (siap_pindah = true)
  const readySowing = await f.post(f.defaultPayload(20));
  assert.equal(readySowing.statusCode, 201);

  // 2: age 5 days -> not ready (siap_pindah = false)
  const youngSowing = await f.post(f.defaultPayload(5));
  assert.equal(youngSowing.statusCode, 201);

  // 3: age 0 days -> not ready
  const todaySowing = await f.post(f.defaultPayload(0));
  assert.equal(todaySowing.statusCode, 201);

  // List all
  const listAll = await f.list();
  assert.equal(listAll.statusCode, 200);
  assert.equal(listAll.json().data.length, 3);
  assert.equal(listAll.json().meta.total, 3);

  // Filter siap_pindah=1
  const listReady = await f.list('siap_pindah=1');
  assert.equal(listReady.statusCode, 200);
  assert.equal(listReady.json().data.length, 1);
  assert.equal(listReady.json().data[0].id_penyemaian, readySowing.json().data.id_penyemaian);
  assert.equal(listReady.json().data[0].siap_pindah, true);
  assert.ok(listReady.json().data[0].usia_hari >= 15);

  // Update youngSowing to 'selesai'
  await f.patch(youngSowing.json().data.id_penyemaian, { status_penyemaian: 'selesai' });

  // Filter status_penyemaian=aktif
  const listAktif = await f.list('status_penyemaian=aktif');
  assert.equal(listAktif.json().data.length, 2);

  // Filter status_penyemaian=selesai
  const listSelesai = await f.list('status_penyemaian=selesai');
  assert.equal(listSelesai.json().data.length, 1);
  assert.equal(listSelesai.json().data[0].id_penyemaian, youngSowing.json().data.id_penyemaian);
});

test('N-05: Get sowing detail includes calculated age, readiness, and consumed stock breakdown', async (t) => {
  const f = await nurseryFixture(t);
  const created = await f.post(f.defaultPayload(16));
  assert.equal(created.statusCode, 201);
  const id = created.json().data.id_penyemaian;

  const detail = await f.get(id);
  assert.equal(detail.statusCode, 200, detail.body);
  const d = detail.json().data;
  assert.equal(d.id_penyemaian, id);
  assert.equal(d.usia_hari, 16);
  assert.equal(d.siap_pindah, true);
  assert.equal(d.stok_konsumsi.length, 1);
  assert.equal(d.stok_konsumsi[0].id_inventaris, f.items[0].id_inventaris);
  assert.equal(d.stok_konsumsi[0].jumlah, '5');
  assert.equal(d.stok_konsumsi[0].satuan, 'gram');

  // Nonexistent id returns 404
  const notFound = await f.get('999999');
  expectError(notFound, 404, 'PENYEMAIAN_NOT_FOUND');
});

test('N-06: PATCH jumlah_benih enforces capacity >= already moved plants', async (t) => {
  const f = await nurseryFixture(t);
  const created = await f.post(f.defaultPayload());
  const id = created.json().data.id_penyemaian;

  // Insert a mock bed and moved plant record (50 plants moved)
  await f.db.execute("INSERT INTO meja_tanam (kode_meja, jumlah_lubang) VALUES ('M-1', 200)");
  await f.db.execute({
    sql: `INSERT INTO pemindahan (id_penyemaian, id_meja, tanggal_pemindahan, jumlah_tanaman)
      VALUES (?, 1, '2026-10-04', 50)`,
    args: [id],
  });

  // PATCH jumlah_benih to 60 (>= 50) -> success
  const okPatch = await f.patch(id, { jumlah_benih: 60 });
  assert.equal(okPatch.statusCode, 200, okPatch.body);
  assert.equal(okPatch.json().data.jumlah_benih, 60);

  // PATCH jumlah_benih to 40 (< 50) -> 409 SOWING_UNDERCAPACITY
  const badPatch = await f.patch(id, { jumlah_benih: 40 });
  expectError(badPatch, 409, 'SOWING_UNDERCAPACITY');
});

test('N-07: PATCH status_penyemaian bumps version and invalid status is rejected by trigger', async (t) => {
  const f = await nurseryFixture(t);
  const created = await f.post(f.defaultPayload());
  const id = created.json().data.id_penyemaian;
  assert.equal(created.json().data.version, '1');

  // Update status to 'selesai'
  const patchRes = await f.patch(id, { status_penyemaian: 'selesai', keterangan: 'Semua bibit dipindahkan' });
  assert.equal(patchRes.statusCode, 200, patchRes.body);
  assert.equal(patchRes.json().data.status_penyemaian, 'selesai');
  assert.equal(patchRes.json().data.keterangan, 'Semua bibit dipindahkan');
  assert.equal(patchRes.json().data.version, '2');

  // Trigger test: direct SQL insert or update with invalid status
  await assert.rejects(
    () => f.db.execute({
      sql: "INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian) VALUES (1, '2026-10-04', 10, 'invalid_status')",
    }),
    /status_penyemaian harus aktif atau selesai/,
  );
});

test('N-08: Inactive inventory rejected during material consumption with atomic rollback', async (t) => {
  const f = await nurseryFixture(t);

  // Deactivate item
  const deact = await f.app.inject({
    method: 'POST',
    url: `/api/v1/inventaris/${f.items[0].id_inventaris}/deactivate`,
    headers: f.headers,
  });
  assert.equal(deact.statusCode, 200);

  // Attempt sowing creation
  const res = await f.post(f.defaultPayload());
  expectError(res, 422, 'INVENTARIS_NOT_AVAILABLE');

  // Verify rollback: no penyemaian inserted
  const sowings = (await f.db.execute('SELECT COUNT(*) AS total FROM penyemaian')).rows[0];
  assert.equal(sowings.total, 0);
});

test('N-09: Insufficient stock balance rolls back entire sowing creation', async (t) => {
  const f = await nurseryFixture(t);

  // Request 9999 grams (available is 500)
  const excessivePayload = {
    ...f.defaultPayload(),
    materials: [{ id_inventaris: f.items[0].id_inventaris, jumlah: '9999', satuan: f.items[0].satuan }],
  };

  const res = await f.post(excessivePayload);
  expectError(res, 409, 'INSUFFICIENT_STOCK');

  // Verify no orphaned records
  const count = (await f.db.execute('SELECT COUNT(*) AS total FROM penyemaian')).rows[0];
  assert.equal(count.total, 0);

  // Verify stock balance remained unchanged
  const saldoRes = await f.app.inject({
    url: `/api/v1/inventaris/${f.items[0].id_inventaris}/saldo`,
    headers: f.headers,
  });
  assert.equal(saldoRes.json().data.saldo, '500');
});

test('N-10: Authorization matrix: petani and pegawai have write, invalid header rejected', async (t) => {
  const f = await nurseryFixture(t);

  // Petani creates sowing -> 201 OK
  const petaniPost = await f.app.inject({
    method: 'POST',
    url: '/api/v1/penyemaian',
    headers: { ...f.reader, 'idempotency-key': randomUUID() },
    payload: f.defaultPayload(),
  });
  assert.equal(petaniPost.statusCode, 201, petaniPost.body);
  const id = petaniPost.json().data.id_penyemaian;

  // Petani updates sowing -> 200 OK
  const petaniPatch = await f.app.inject({
    method: 'PATCH',
    url: `/api/v1/penyemaian/${id}`,
    headers: { ...f.reader, 'idempotency-key': randomUUID() },
    payload: { jumlah_benih: 150 },
  });
  assert.equal(petaniPatch.statusCode, 200, petaniPatch.body);

  // Pegawai creates sowing -> 201
  const created = await f.post(f.defaultPayload());
  assert.equal(created.statusCode, 201);

  // Create without idempotency-key defaults to randomUUID -> 201 OK
  const withoutKey = await f.app.inject({
    method: 'POST',
    url: '/api/v1/penyemaian',
    headers: f.headers,
    payload: f.defaultPayload(),
  });
  assert.equal(withoutKey.statusCode, 201, withoutKey.body);

  // Invalid idempotency-key -> 400 VALIDATION_ERROR
  const invalidKey = await f.app.inject({
    method: 'POST',
    url: '/api/v1/penyemaian',
    headers: { ...f.headers, 'idempotency-key': 'not-a-uuid' },
    payload: f.defaultPayload(),
  });
  expectError(invalidKey, 400, 'VALIDATION_ERROR');

  // Petani reads sowing -> 200 OK
  const petaniGet = await f.get(id);
  assert.equal(petaniGet.statusCode, 200);

  // Anonymous request -> 401 UNAUTHENTICATED
  const anon = await f.app.inject({
    method: 'GET',
    url: '/api/v1/penyemaian',
  });
  expectError(anon, 401, 'UNAUTHENTICATED');
});

test('N-11: ID representation preserves signed64 format across nursery responses', async (t) => {
  const f = await nurseryFixture(t);
  const created = await f.post(f.defaultPayload());
  assert.equal(created.statusCode, 201);
  const data = created.json().data;

  assert.equal(typeof data.id_penyemaian, 'string');
  assert.equal(typeof data.id_user, 'string');

  const detail = (await f.get(data.id_penyemaian)).json().data;
  assert.equal(typeof detail.id_penyemaian, 'string');
  assert.equal(typeof detail.id_user, 'string');
  for (const item of detail.stok_konsumsi) {
    assert.equal(typeof item.id_stok, 'string');
    assert.equal(typeof item.id_detail_stok, 'string');
    assert.equal(typeof item.id_inventaris, 'string');
  }

  const list = (await f.list()).json().data;
  for (const row of list) {
    assert.equal(typeof row.id_penyemaian, 'string');
    assert.equal(typeof row.id_user, 'string');
  }
});

test('N-12: PATCH keeps omitted note; explicit null clears it', async (t) => {
  const f = await nurseryFixture(t);
  const created = await f.post(f.defaultPayload());
  const id = created.json().data.id_penyemaian;
  assert.equal(created.json().data.keterangan, 'Penyemaian batch 1');
  const changed = await f.patch(id, { jumlah_benih: 101 });
  assert.equal(changed.statusCode, 200, changed.body);
  assert.equal(changed.json().data.keterangan, 'Penyemaian batch 1');
  const cleared = await f.patch(id, { keterangan: null });
  assert.equal(cleared.statusCode, 200, cleared.body);
  assert.equal(cleared.json().data.keterangan, null);
});

test('N-13: usia and siap_pindah use the injected Jakarta business clock', async (t) => {
  const f = await nurseryFixture(t);
  const created = await f.post({ ...f.defaultPayload(), tanggal_semai: '2026-09-16' });
  assert.equal(created.statusCode, 201, created.body);
  const id = created.json().data.id_penyemaian;
  assert.equal(created.json().data.usia_hari, 14);
  assert.equal(created.json().data.siap_pindah, false);
  const before = await f.list('siap_pindah=1');
  assert.equal(before.json().meta.total, 0);
  f.advance(17 * 3600 * 1000); // 2026-09-30 17:00Z = 2026-10-01 00:00 Jakarta
  const renewed = { authorization: `Bearer ${(await f.login('petani')).json().data.access_token}` };
  const detail = await f.get(id, renewed);
  assert.equal(detail.json().data.usia_hari, 15);
  assert.equal(detail.json().data.siap_pindah, true);
  const after = await f.list('siap_pindah=1', renewed);
  assert.equal(after.json().meta.total, 1);
});
