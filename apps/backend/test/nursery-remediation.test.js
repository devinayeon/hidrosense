import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { nurseryFixture, expectError } from '../test-support/nursery-fixture.js';
import { password } from '../test-support/fixture.js';

test('Petani persists create/detail/edit; stock consumption and original date stay unchanged', async (t) => {
  const f = await nurseryFixture(t);
  const key = randomUUID();
  const created = await f.post(f.defaultPayload(14), { ...f.reader, 'idempotency-key': key });
  assert.equal(created.statusCode, 201, created.body);
  const first = created.json().data;
  assert.equal(first.id_user, '1');
  assert.equal(first.usia_hari, 14);
  const changed = await f.patch(first.id_penyemaian, { jumlah_benih: 120, keterangan: '' }, f.reader);
  assert.equal(changed.statusCode, 200, changed.body);
  const detail = (await f.get(first.id_penyemaian)).json().data;
  assert.equal(detail.jumlah_benih, 120);
  assert.equal(detail.keterangan, '');
  assert.equal(detail.tanggal_semai, first.tanggal_semai);
  assert.equal(detail.stok_konsumsi.length, 1);
  assert.equal(detail.stok_konsumsi[0].jumlah, '5');
  const replay = await f.post(f.defaultPayload(14), { ...f.reader, 'idempotency-key': key });
  assert.equal(replay.statusCode, 200, replay.body);
  assert.equal(replay.json().replayed, true);
  const balance = await f.app.inject({ url: `/api/v1/inventaris/${f.items[0].id_inventaris}/saldo`, headers: f.reader });
  assert.equal(balance.json().data.saldo, '495');
  const immutable = await f.patch(first.id_penyemaian, { tanggal_semai: f.daysAgo(10) }, f.reader);
  expectError(immutable, 400, 'VALIDATION_ERROR');
});

test('Completed sowings reject edits/reopen but replay their committed completion receipt', async (t) => {
  const f = await nurseryFixture(t);
  const created = await f.post(f.defaultPayload(), f.reader);
  const id = created.json().data.id_penyemaian;
  const key = randomUUID();
  const complete = { status_penyemaian: 'selesai' };
  const headers = { ...f.reader, 'idempotency-key': key };
  assert.equal((await f.patch(id, complete, headers)).statusCode, 200);
  const replay = await f.patch(id, complete, headers);
  assert.equal(replay.statusCode, 200, replay.body);
  assert.equal(replay.json().replayed, true);
  for (const payload of [{ jumlah_benih: 101 }, { keterangan: 'changed' }, { status_penyemaian: 'aktif' }]) {
    expectError(await f.patch(id, payload, f.reader), 409, 'SOWING_COMPLETED');
  }
});

test('Future Jakarta date is rejected atomically, then accepted at Jakarta midnight', async (t) => {
  const f = await nurseryFixture(t);
  const input = { ...f.defaultPayload(), tanggal_semai: '2026-10-01' };
  expectError(await f.post(input, f.reader), 422, 'SOWING_DATE_IN_FUTURE');
  assert.equal((await f.list()).json().meta.total, 0);
  const balance = await f.app.inject({ url: `/api/v1/inventaris/${f.items[0].id_inventaris}/saldo`, headers: f.reader });
  assert.equal(balance.json().data.saldo, '500');
  f.advance(17 * 3600 * 1000);
  const auth = { authorization: `Bearer ${(await f.login('petani')).json().data.access_token}` };
  const created = await f.post(input, auth);
  assert.equal(created.statusCode, 201, created.body);
  assert.equal(created.json().data.usia_hari, 0);
});

test('Ready batch remains readable on page two of a 51-batch catalog', async (t) => {
  const f = await nurseryFixture(t);
  const oldest = (await f.post(f.defaultPayload(15), f.reader)).json().data;
  for (let i = 0; i < 50; i++) {
    assert.equal((await f.post(f.defaultPayload(), f.reader)).statusCode, 201);
  }
  const one = (await f.list('limit=50&page=1')).json();
  const two = (await f.list('limit=50&page=2')).json();
  assert.equal(one.meta.total, 51);
  assert.equal(one.meta.total_pages, 2);
  assert.equal(one.data.some(row => row.siap_pindah), false);
  assert.equal(two.data[0].id_penyemaian, oldest.id_penyemaian);
  assert.equal(two.data[0].siap_pindah, true);
});

test('Real HTTP Petani flow persists after reopening and notifies on Jakarta day 15/16', async (t) => {
  const f = await nurseryFixture(t);
  const origin = await f.app.listen({ host: '127.0.0.1', port: 0 });
  let token;
  const request = async (path, method = 'GET', body, key) => {
    const res = await fetch(`${origin}/api/v1/${path}`, {
      method,
      headers: {
        ...(token ? { authorization: `Bearer ${token}` } : {}),
        ...(body ? { 'content-type': 'application/json' } : {}),
        ...(key ? { 'idempotency-key': key } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const json = await res.json();
    assert.ok(res.ok, JSON.stringify(json));
    return json;
  };
  const login = async () => {
    token = (await request('auth/login', 'POST', { username: 'petani', password })).data.access_token;
  };
  await login();
  const payload = f.defaultPayload(14), key = randomUUID();
  const created = await request('penyemaian', 'POST', payload, key);
  const id = created.data.id_penyemaian;
  assert.equal(created.data.id_user, '1');
  assert.equal(created.data.siap_pindah, false);
  assert.equal((await request('penyemaian')).data[0].id_penyemaian, id);
  await request(`penyemaian/${id}`, 'PATCH', { jumlah_benih: 120, keterangan: '' }, randomUUID());
  const reopened = (await request(`penyemaian/${id}`)).data;
  assert.equal(reopened.jumlah_benih, 120);
  assert.equal(reopened.keterangan, '');
  assert.equal(reopened.stok_konsumsi[0].jumlah, '5');
  assert.equal((await request('penyemaian', 'POST', payload, key)).replayed, true);
  assert.equal((await request(`inventaris/${f.items[0].id_inventaris}/saldo`)).data.saldo, '495');
  f.advance(17 * 3600 * 1000);
  await login();
  const ready = (await request(`penyemaian/${id}`)).data;
  assert.equal(ready.usia_hari, 15);
  assert.equal(ready.siap_pindah, true);
  assert.equal((await request('penyemaian?siap_pindah=1')).data[0].id_penyemaian, id);
  f.advance(24 * 3600 * 1000);
  await login();
  const day16 = (await request(`penyemaian/${id}`)).data;
  assert.equal(day16.usia_hari, 16);
  assert.equal(day16.siap_pindah, true);
  t.diagnostic(JSON.stringify({ actor: 'petani', transport: 'HTTP', create: true, reopen: true,
    edit: true, replay: true, seed_stock: '495', readiness: [14, 15, 16], port: new URL(origin).port }));
});
