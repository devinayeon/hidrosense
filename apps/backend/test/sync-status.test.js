// Permintaan pemilik (2026-11-23): "Terakhir sinkron" kembali ke jam contoh setelah pengguna
// keluar dari menu Sinkron. Server menyimpan kapan satu perangkat terakhir selesai sinkron.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { bearer, fixture } from '../test-support/fixture.js';

const DEVICE_A = '3f1c2a9e-0b7d-4a55-9c3e-1d2f4b6a8c01';
const DEVICE_B = '9a8b7c6d-5e4f-4321-8abc-0123456789ab';

async function setup(t) {
  const f = await fixture(t);
  const petani = bearer((await f.login('petani')).json().data.access_token);
  const pegawai = bearer((await f.login('pegawai')).json().data.access_token);
  const signIn = async (username) => bearer((await f.login(username)).json().data.access_token);
  const status = (headers, device = DEVICE_A) => f.app.inject({
    method: 'GET', url: `/api/v1/sync/status?device_id=${device}`, headers,
  });
  const mark = (headers, device = DEVICE_A) => f.app.inject({
    method: 'POST', url: '/api/v1/sync/status', headers, payload: { device_id: device },
  });
  return { ...f, petani, pegawai, signIn, status, mark };
}

test('a device that never synced has no last sync time', async (t) => {
  const f = await setup(t);
  const response = await f.status(f.petani);
  assert.equal(response.statusCode, 200, response.body);
  assert.deepEqual(response.json().data, { last_synced_at: null });
});

test('the last sync time survives leaving the screen and signing in again', async (t) => {
  const f = await setup(t);
  const marked = await f.mark(f.petani);
  assert.equal(marked.statusCode, 200, marked.body);
  assert.equal(marked.json().data.last_synced_at, '2026-09-30T00:00:00.000Z');

  f.advance(3 * 60 * 60 * 1000);
  const again = bearer((await f.login('petani')).json().data.access_token);
  const read = await f.status(again);
  assert.equal(read.statusCode, 200, read.body);
  assert.equal(read.json().data.last_synced_at, '2026-09-30T00:00:00.000Z');
});

test('a later sync moves the time forward and never backwards', async (t) => {
  const f = await setup(t);
  await f.mark(f.petani);
  f.advance(90 * 60 * 1000);
  const petani = await f.signIn('petani'); // token lama sudah kedaluwarsa
  const later = await f.mark(petani);
  assert.equal(later.json().data.last_synced_at, '2026-09-30T01:30:00.000Z');
  assert.equal((await f.status(petani)).json().data.last_synced_at, '2026-09-30T01:30:00.000Z');
  // Same row, one per device: no duplicate rows from repeated marks.
  assert.equal((await f.db.execute('SELECT COUNT(*) AS n FROM sync_checkpoints')).rows[0].n, 1);
});

test('each device and each user keeps its own last sync time', async (t) => {
  const f = await setup(t);
  await f.mark(f.petani, DEVICE_A);
  f.advance(60 * 60 * 1000);
  const petani = await f.signIn('petani');
  const pegawai = await f.signIn('pegawai');
  assert.equal((await f.status(petani, DEVICE_B)).json().data.last_synced_at, null);
  assert.equal((await f.status(pegawai, DEVICE_A)).json().data.last_synced_at, null);
  await f.mark(pegawai, DEVICE_A);
  assert.equal((await f.status(petani, DEVICE_A)).json().data.last_synced_at, '2026-09-30T00:00:00.000Z');
  assert.equal((await f.status(pegawai, DEVICE_A)).json().data.last_synced_at, '2026-09-30T01:00:00.000Z');
});

test('input and session are checked', async (t) => {
  const f = await setup(t);
  assert.equal((await f.status(f.petani, 'bukan-uuid')).statusCode, 400);
  assert.equal((await f.app.inject({ url: '/api/v1/sync/status', headers: f.petani })).statusCode, 400);
  assert.equal((await f.app.inject({
    url: `/api/v1/sync/status?device_id=${DEVICE_A}&x=1`, headers: f.petani,
  })).statusCode, 400);
  assert.equal((await f.app.inject({
    method: 'POST', url: '/api/v1/sync/status', headers: f.petani, payload: { device_id: DEVICE_A, synced_at: 1 },
  })).statusCode, 400);
  assert.equal((await f.app.inject({
    method: 'POST', url: '/api/v1/sync/status', headers: f.petani, payload: {},
  })).statusCode, 400);
  assert.equal((await f.app.inject({ url: `/api/v1/sync/status?device_id=${DEVICE_A}` })).statusCode, 401);
  assert.equal((await f.app.inject({
    method: 'POST', url: '/api/v1/sync/status', payload: { device_id: DEVICE_A },
  })).statusCode, 401);
});
