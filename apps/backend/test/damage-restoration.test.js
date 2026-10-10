import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { fixture, bearer } from '../test-support/fixture.js';

function check(response, status, code) {
  assert.equal(response.statusCode, status, response.body);
  if (code) assert.equal(response.json().error.code, code);
}

test('damage restoration respects table capacity and retries a rolled back operation', async (t) => {
  const f = await fixture(t);
  const headers = bearer((await f.login('pegawai')).json().data.access_token);
  const send = (method, path, payload, extra = {}) => f.app.inject({
    method, url: `/api/v1/${path}`, payload, headers: { ...headers, ...extra },
  });
  await f.db.executeMultiple(`
    INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian)
    VALUES (2, '2026-09-01', 500, 'aktif');
    INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja)
    VALUES ('M-01', 250, 'tersedia');
  `);
  const transfer = (count) => send('POST', 'pemindahan', {
    id_penyemaian: '1', id_meja: '1', tanggal_pemindahan: '2026-09-16', jumlah_tanaman: count,
  });
  const initialTransfer = await transfer(250);
  check(initialTransfer, 201);
  const damage = await send('POST', 'kerusakan', {
    id_pemindahan: initialTransfer.json().data.id_pemindahan,
    tanggal_kejadian: '2026-09-20', jumlah_tanaman: 5, jenis_kerusakan: 'Busuk akar',
  });
  check(damage, 201);
  check(await transfer(5), 201);

  const original = damage.json().data;
  const path = `kerusakan/${original.id_kerusakan}`;
  const operationKey = randomUUID();
  const extra = { 'idempotency-key': operationKey };
  const correction = { jumlah_tanaman: 3, jenis_kerusakan: 'Koreksi busuk akar' };
  const receiptCount = async () => Number((await f.db.execute({
    sql: 'SELECT COUNT(*) AS total FROM sync_operations WHERE operation_key = ?', args: [operationKey],
  })).rows[0].total);
  const version = async () => String((await f.db.execute({
    sql: "SELECT version FROM sync_resource_versions WHERE resource_type = 'kerusakan_tanaman' AND public_id = ?",
    args: [original.public_id],
  })).rows[0].version);

  check(await send('PATCH', path, correction, extra), 409, 'DAMAGE_RESTORE_EXCEEDS_TABLE_CAPACITY');
  const afterFailure = await send('GET', path);
  check(afterFailure, 200);
  assert.deepEqual(afterFailure.json().data, original);
  assert.equal(await receiptCount(), 0);
  assert.equal(await version(), '1');
  for (const tablePath of ['meja-tanam', 'meja-tanam/1']) {
    const response = await send('GET', tablePath);
    check(response, 200);
    const table = tablePath === 'meja-tanam' ? response.json().data[0] : response.json().data;
    assert.equal(table.tanaman_aktif, 250);
    assert.equal(table.kapasitas_tersedia, 0);
  }

  check(await send('PATCH', 'meja-tanam/1', { jumlah_lubang: 252 }), 200);
  const corrected = await send('PATCH', path, correction, extra);
  check(corrected, 200);
  assert.equal(corrected.json().data.jumlah_tanaman, 3);
  assert.equal(corrected.json().data.jenis_kerusakan, correction.jenis_kerusakan);
  assert.equal(corrected.json().data.version, '2');
  assert.equal(await receiptCount(), 1);
  assert.equal(await version(), '2');

  const replay = await send('PATCH', path, correction, extra);
  check(replay, 200);
  assert.equal(replay.json().replayed, true);
  assert.deepEqual(replay.json().data, corrected.json().data);
  assert.equal(await receiptCount(), 1);
  assert.equal(await version(), '2');
  const table = await send('GET', 'meja-tanam/1');
  check(table, 200);
  assert.equal(table.json().data.tanaman_aktif, 252);
  assert.equal(table.json().data.kapasitas_tersedia, 0);
});
