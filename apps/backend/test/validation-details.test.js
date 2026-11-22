import assert from 'node:assert/strict';
import { test } from 'node:test';
import { bearer, fixture } from '../test-support/fixture.js';

async function petani(t) {
  const f = await fixture(t);
  const token = (await f.login('petani')).json().data.access_token;
  const post = (url, payload) => f.app.inject({
    method: 'POST', url: `/api/v1/${url}`, headers: bearer(token), payload,
  });
  return { f, post };
}

const detailFor = (response, field) => response.json().error.details.find((d) => d.field === field);

test('a number over the limit names the field and the limit', async (t) => {
  const { post } = await petani(t);
  const response = await post('meja-tanam', { kode_meja: 'M-1', jumlah_lubang: 1231 });
  assert.equal(response.statusCode, 400);
  const { error } = response.json();
  assert.equal(error.code, 'VALIDATION_ERROR');
  assert.equal(error.message, 'Input tidak sesuai kontrak API.');
  assert.deepEqual(detailFor(response, 'jumlah_lubang'), { field: 'jumlah_lubang', message: 'Maksimal 1000.' });
});

test('a text over the limit says how many characters are allowed', async (t) => {
  const { post } = await petani(t);
  const response = await post('meja-tanam', { kode_meja: 'x'.repeat(31), jumlah_lubang: 10 });
  assert.equal(response.statusCode, 400);
  assert.deepEqual(detailFor(response, 'kode_meja'), { field: 'kode_meja', message: 'Maksimal 30 karakter.' });
});

test('a missing required field is reported as required', async (t) => {
  const { post } = await petani(t);
  const response = await post('meja-tanam', { jumlah_lubang: 10 });
  assert.equal(response.statusCode, 400);
  assert.deepEqual(detailFor(response, 'kode_meja'), { field: 'kode_meja', message: 'Wajib diisi.' });
});

test('an unknown field is reported by name', async (t) => {
  const { post } = await petani(t);
  const response = await post('meja-tanam', { kode_meja: 'M-1', jumlah_lubang: 10, warna: 'biru' });
  assert.equal(response.statusCode, 400);
  assert.deepEqual(detailFor(response, 'warna'), { field: 'warna', message: 'Field tidak dikenal.' });
});

test('details never echo the value that was sent', async (t) => {
  const { post } = await petani(t);
  const secret = 'rahasia-yang-tidak-boleh-bocor';
  const response = await post('meja-tanam', { kode_meja: secret.repeat(3), jumlah_lubang: 10 });
  assert.equal(response.statusCode, 400);
  assert.ok(!response.body.includes(secret), 'response must not contain the submitted value');
});

test('errors that are not validation errors carry no details', async (t) => {
  const { f } = await petani(t);
  const response = await f.app.inject({ method: 'GET', url: '/api/v1/meja-tanam' });
  assert.equal(response.statusCode, 401);
  assert.equal('details' in response.json().error, false);
});
