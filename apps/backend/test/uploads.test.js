import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { readConfig } from '../src/config.ts';
import { signCloudinaryParams } from '../src/features/uploads/signature.ts';
import { fixture, bearer } from '../test-support/fixture.js';

// Nilai sintetis. Secret asli tidak pernah ditulis di repo.
const env = { CLOUDINARY_CLOUD_NAME: 'democloud', CLOUDINARY_API_KEY: '123456789012345', CLOUDINARY_API_SECRET: 'unit-test-secret' };

async function setup(t, options = {}) {
  const f = await fixture(t, options);
  const token = (await f.login('petani')).json().data.access_token;
  const sign = (extra = {}) => f.app.inject({
    method: 'POST', url: '/api/v1/unggahan/tanda-tangan', headers: { ...bearer(token), ...extra },
  });
  return { ...f, sign };
}

test('tanda tangan cocok dengan contoh resmi dokumentasi Cloudinary', () => {
  const signature = signCloudinaryParams(
    { eager: 'w_400,h_300,c_pad|w_260,h_200,c_crop', public_id: 'sample_image', timestamp: 1315060510 },
    'abcd',
  );
  assert.equal(signature, 'bfd09f95f331f558cbd1320e67aa8d488770583e');
});

test('urutan parameter tidak memengaruhi tanda tangan', () => {
  assert.equal(
    signCloudinaryParams({ timestamp: 1, folder: 'a' }, 's'),
    signCloudinaryParams({ folder: 'a', timestamp: 1 }, 's'),
  );
});

test('endpoint mengembalikan tanda tangan yang bisa diverifikasi dan tidak membocorkan secret', async (t) => {
  const s = await setup(t, { env });
  const res = await s.sign();
  assert.equal(res.statusCode, 200, res.body);
  const { data } = res.json();
  assert.equal(data.cloud_name, 'democloud');
  assert.equal(data.api_key, '123456789012345');
  assert.equal(data.timestamp, Math.floor(s.clock() / 1000));
  assert.equal(data.folder, 'hidrosense/pindai/1', 'folder dikunci server per pengguna');
  assert.equal(data.upload_url, 'https://api.cloudinary.com/v1_1/democloud/image/upload');
  const expected = createHash('sha1').update(`folder=${data.folder}&timestamp=${data.timestamp}unit-test-secret`).digest('hex');
  assert.equal(data.signature, expected);
  assert.ok(!res.body.includes('unit-test-secret'), 'api_secret tidak boleh muncul di respons');
});

test('tanpa konfigurasi: 503 UPLOAD_NOT_CONFIGURED, bukan tanda tangan palsu', async (t) => {
  const s = await setup(t);
  const res = await s.sign();
  assert.equal(res.statusCode, 503);
  assert.equal(res.json().error.code, 'UPLOAD_NOT_CONFIGURED');
});

test('tanpa token 401', async (t) => {
  const s = await setup(t, { env });
  const res = await s.app.inject({ method: 'POST', url: '/api/v1/unggahan/tanda-tangan' });
  assert.equal(res.statusCode, 401);
});

test('konfigurasi setengah terisi ditolak saat start, nilai kosong dianggap tidak diisi', () => {
  assert.throws(() => readConfig({ NODE_ENV: 'production', CLOUDINARY_CLOUD_NAME: 'democloud' }), /must be set together/);
  assert.equal(readConfig({ NODE_ENV: 'development', CLOUDINARY_CLOUD_NAME: 'democloud', CLOUDINARY_API_KEY: '123456' }).cloudinary, null);
  assert.equal(
    readConfig({ NODE_ENV: 'test', CLOUDINARY_CLOUD_NAME: '', CLOUDINARY_API_KEY: '', CLOUDINARY_API_SECRET: '' }).cloudinary,
    null,
  );
  assert.throws(() => readConfig({ NODE_ENV: 'test', ...env, CLOUDINARY_API_KEY: 'bukan-angka' }));
});

// .env.example di-commit: secret asli pernah sempat tertulis di sana (2026-11-23) sebelum commit.
test('.env.example tidak pernah berisi nilai api_secret', () => {
  const example = readFileSync(new URL('../.env.example', import.meta.url), 'utf8');
  const secret = example.match(/^CLOUDINARY_API_SECRET=(.*)$/m);
  assert.ok(secret, 'kunci CLOUDINARY_API_SECRET tetap terdokumentasi');
  assert.equal(secret[1].trim(), '', 'nilai secret hanya di .env server, bukan di .env.example');
});
