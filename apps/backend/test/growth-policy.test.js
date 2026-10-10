import assert from 'node:assert/strict';
import { test } from 'node:test';
import { fixture, bearer } from '../test-support/fixture.js';

function check(response, status, code) {
  assert.equal(response.statusCode, status, response.body);
  if (code) assert.equal(response.json().error.code, code);
}

async function setup(t) {
  const f = await fixture(t);
  let headers;
  const authenticate = async () => {
    headers = bearer((await f.login('pegawai')).json().data.access_token);
  };
  await authenticate();
  await f.db.executeMultiple(`
    INSERT INTO penyemaian (id_user, tanggal_semai, jumlah_benih, status_penyemaian)
    VALUES (2, '2026-09-01', 500, 'aktif');
    INSERT INTO meja_tanam (kode_meja, jumlah_lubang, status_meja)
    VALUES ('M-01', 250, 'tersedia');
  `);
  const send = (method, path, payload) => f.app.inject({
    method, url: `/api/v1/${path}`, payload, headers,
  });
  const transfer = (body = {}) => send('POST', 'pemindahan', {
    id_penyemaian: '1', id_meja: '1', tanggal_pemindahan: '2026-09-16', jumlah_tanaman: 10,
    ...body,
  });
  const damage = (body = {}) => send('POST', 'kerusakan', {
    id_pemindahan: '1', tanggal_kejadian: '2026-09-20', jumlah_tanaman: 1,
    jenis_kerusakan: 'Busuk akar', ...body,
  });
  return { ...f, authenticate, send, transfer, damage };
}

test('transfer requires fifteen full days after sowing', async (t) => {
  const f = await setup(t);
  check(await f.transfer({ tanggal_pemindahan: '2026-09-15' }), 400, 'SEEDLING_NOT_READY');
  const accepted = await f.transfer({ tanggal_pemindahan: '2026-09-16' });
  check(accepted, 201);
  assert.equal(accepted.json().data.umur_semai_hari, 15);
  assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM pemindahan')).rows[0].n, 1);
});

test('transfer uses Jakarta current date at the UTC day boundary', async (t) => {
  const f = await setup(t);
  check(await f.transfer({ tanggal_pemindahan: '2026-09-30' }), 201);
  check(await f.transfer({ tanggal_pemindahan: '2026-10-01' }), 400, 'INVALID_TRANSFER_DATE');
  f.advance(18 * 60 * 60 * 1000);
  await f.authenticate();
  assert.equal(new Date(f.clock()).toISOString(), '2026-09-30T18:00:00.000Z');
  check(await f.transfer({ tanggal_pemindahan: '2026-10-01' }), 201);
  check(await f.transfer({ tanggal_pemindahan: '2026-10-02' }), 400, 'INVALID_TRANSFER_DATE');
  assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM pemindahan')).rows[0].n, 2);
});

test('only tersedia tables accept transfers, including custom legacy statuses', async (t) => {
  const f = await setup(t);
  for (const status of ['tersedia', 'penuh', 'pemeliharaan', 'perbaikan', 'rusak', 'nonaktif', 'custom']) {
    await f.db.execute({ sql: 'UPDATE meja_tanam SET status_meja = ? WHERE id_meja = 1', args: [status] });
    const response = await f.transfer({ jumlah_tanaman: 1 });
    check(response, status === 'tersedia' ? 201 : 409, status === 'tersedia' ? undefined : 'TABLE_NOT_AVAILABLE');
  }
  assert.equal((await f.db.execute('SELECT SUM(jumlah_tanaman) AS total FROM pemindahan')).rows[0].total, 1);
});

test('damage creation and correction use transfer and Jakarta date boundaries', async (t) => {
  const f = await setup(t);
  check(await f.transfer(), 201);
  check(await f.damage({ tanggal_kejadian: '2026-09-15' }), 400, 'INVALID_DAMAGE_DATE');
  const first = await f.damage({ tanggal_kejadian: '2026-09-16' });
  check(first, 201);
  check(await f.damage({ tanggal_kejadian: '2026-09-30' }), 201);
  check(await f.damage({ tanggal_kejadian: '2026-10-01' }), 400, 'VALIDATION_ERROR');
  const path = `kerusakan/${first.json().data.id_kerusakan}`;
  check(await f.send('PATCH', path, { tanggal_kejadian: '2026-09-15' }), 400, 'INVALID_DAMAGE_DATE');
  check(await f.send('PATCH', path, { tanggal_kejadian: '2026-10-01' }), 400, 'VALIDATION_ERROR');
  const unchanged = await f.send('GET', path);
  check(unchanged, 200);
  assert.deepEqual(unchanged.json().data, first.json().data);
  check(await f.send('PATCH', path, { tanggal_kejadian: '2026-09-30' }), 200);
  check(await f.send('PATCH', path, { tanggal_kejadian: '2026-09-16' }), 200);

  f.advance(18 * 60 * 60 * 1000);
  await f.authenticate();
  check(await f.damage({ tanggal_kejadian: '2026-10-01' }), 201);
  check(await f.damage({ tanggal_kejadian: '2026-10-02' }), 400, 'VALIDATION_ERROR');
  const corrected = await f.send('PATCH', path, { tanggal_kejadian: '2026-10-01' });
  check(corrected, 200);
  check(await f.send('PATCH', path, { tanggal_kejadian: '2026-10-02' }), 400, 'VALIDATION_ERROR');
  const after = await f.send('GET', path);
  check(after, 200);
  assert.deepEqual(after.json().data, corrected.json().data);
});

test('damage count excludes harvested plants on creation and correction', async (t) => {
  const f = await setup(t);
  check(await f.transfer({ jumlah_tanaman: 100 }), 201);
  await f.db.executeMultiple(`
    INSERT INTO panen (id_user, tanggal_panen) VALUES (2, '2026-09-30');
    INSERT INTO detail_panen (id_panen, id_pemindahan, jumlah_tanaman, berat)
    VALUES (1, 1, 60, 6);
  `);
  const first = await f.damage({ jumlah_tanaman: 30 });
  check(first, 201);
  check(await f.damage({ jumlah_tanaman: 11 }), 409, 'DAMAGE_EXCEEDS_ACTIVE');
  check(await f.damage({ jumlah_tanaman: 10 }), 201);
  const path = `kerusakan/${first.json().data.id_kerusakan}`;
  check(await f.send('PATCH', path, { jumlah_tanaman: 31 }), 409, 'DAMAGE_EXCEEDS_ACTIVE');
  const unchanged = await f.send('GET', path);
  check(unchanged, 200);
  assert.deepEqual(unchanged.json().data, first.json().data);
  const transfer = await f.send('GET', 'pemindahan/1');
  check(transfer, 200);
  assert.equal(transfer.json().data.tanaman_aktif, 0);
  check(await f.send('PATCH', path, { jumlah_tanaman: 29 }), 200);
  const restored = await f.send('GET', 'pemindahan/1');
  check(restored, 200);
  assert.equal(restored.json().data.tanaman_aktif, 1);
});
